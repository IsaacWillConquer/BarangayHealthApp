import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/validators.dart';
import 'profile_repository.dart' show RepoResult;

/// Surveys, questions, and responses for the signed-in resident.
///
/// Mirrors `src/api/residentSurveysLocal.js`. Field names are PascalCase to match
/// documents written by the web portal, including `AnswerText`, which staff
/// response tallies depend on.
class SurveyRepository {
  SurveyRepository({required this.residentId, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String residentId;
  final FirebaseFirestore _db;

  static const _residents = 'residents';
  static const _surveys = 'surveys';
  static const _questions = 'surveyQuestions';
  static const _responses = 'surveyResponses';
  static const _logs = 'logs';

  /// A survey is answerable only when it is Active and today falls inside its
  /// optional `OpenAt`/`CloseAt` window.
  ///
  /// The stored values are `YYYY-MM-DD` strings, so they are compared
  /// lexically against the local date rather than parsed.
  static bool isWithinWindow(Map<String, dynamic> survey, String today) {
    if (survey['Status'] != 'Active') return false;
    final open = survey['OpenAt'] as String?;
    if (open != null && open.isNotEmpty && today.compareTo(open) < 0) {
      return false;
    }
    final close = survey['CloseAt'] as String?;
    if (close != null && close.isNotEmpty && today.compareTo(close) > 0) {
      return false;
    }
    return true;
  }

  Future<Set<String>> _answeredSurveyIds() async {
    final snap = await _db
        .collection(_responses)
        .where('ResidentID', isEqualTo: residentId)
        .get();
    return snap.docs.map((d) => d.get('SurveyID') as String? ?? '').toSet();
  }

  /// Active, in-window surveys the resident has not answered yet.
  ///
  /// The already-answered filter is applied client-side, matching
  /// `residentSurveysLocal.js`. Firestore's `not-in` only accepts a fixed set,
  /// so a client-side check is the simpler and identical-behaviour option here.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  activeSurveys() async {
    final answered = await _answeredSurveyIds();
    final snap = await _db
        .collection(_surveys)
        .where('Status', isEqualTo: 'Active')
        .get();
    final today = todayString();
    return snap.docs
        .where((d) => !answered.contains(d.id))
        .where((d) => isWithinWindow(d.data(), today))
        .toList();
  }

  /// The resident's past submissions, newest first.
  Future<List<Map<String, dynamic>>> completedSurveys() async {
    final snap = await _db
        .collection(_responses)
        .where('ResidentID', isEqualTo: residentId)
        .get();
    final titles = <String, String>{};
    for (final doc in snap.docs) {
      final id = doc.get('SurveyID') as String?;
      if (id == null || titles.containsKey(id)) continue;
      final survey = await _db.collection(_surveys).doc(id).get();
      titles[id] = (survey.data()?['Title'] as String?) ?? '(deleted survey)';
    }
    final rows = snap.docs.map((d) {
      final id = d.get('SurveyID') as String?;
      return {
        'SurveyID': id,
        'ResponseID': d.id,
        'Title': (id == null ? null : titles[id]) ?? '(deleted survey)',
        'SubmittedAt': d.get('SubmittedAt'),
      };
    }).toList();
    rows.sort(
      (a, b) => (b['SubmittedAt'] as String? ?? '').compareTo(
        a['SubmittedAt'] as String? ?? '',
      ),
    );
    return rows;
  }

  /// Questions for [surveyId], ordered by `OrderIndex`.
  Future<List<Map<String, dynamic>>> questions(String surveyId) async {
    final snap = await _db
        .collection(_questions)
        .where('SurveyID', isEqualTo: surveyId)
        .get();
    final rows = snap.docs
        .map((d) => {'QuestionID': d.id, ...d.data()})
        .toList();
    rows.sort(
      (a, b) => (a['OrderIndex'] as num? ?? 0).compareTo(
        b['OrderIndex'] as num? ?? 0,
      ),
    );
    return rows;
  }

  /// The resident's own answers for a submitted response, ordered by question.
  ///
  /// Mirrors `getRespondentAnswers` in `src/api/surveysLocal.js`, with one
  /// hardening: the response must belong to [residentId], so a stale or guessed
  /// id can never surface another resident's answers.
  ///
  /// Throws when the response is missing or unreadable, the same way [questions]
  /// does, so callers can present an empty state on a single catch.
  Future<List<SubmittedAnswer>> responseAnswers(String responseId) async {
    final snap = await _db.collection(_responses).doc(responseId).get();
    if (!snap.exists || snap.get('ResidentID') != residentId) {
      throw StateError('Response not found.');
    }

    final surveyId = snap.get('SurveyID') as String? ?? '';
    final byQuestion = <String, Map<String, dynamic>>{
      for (final q in await questions(surveyId)) q['QuestionID'] as String: q,
    };

    final rows = <SubmittedAnswer>[];
    for (final entry in snap.get('Answers') as List? ?? const []) {
      if (entry is! Map<String, dynamic>) continue;
      final id = entry['QuestionID'] as String?;
      final question = id == null ? null : byQuestion[id];
      // An answer whose question was deleted is dropped rather than shown with
      // no label, matching the web client.
      if (id == null || question == null) continue;
      rows.add(
        SubmittedAnswer(
          questionId: id,
          questionText: (question['QuestionText'] as String?) ?? '',
          type: questionType(question),
          value: answerDisplayValue(question, entry),
        ),
      );
    }
    return rows;
  }

  /// A question with no or an unrecognised `Type` is treated as free text, the
  /// same way an unknown type falls through to the default answer field.
  static String questionType(Map<String, dynamic> q) =>
      q['Type'] as String? ?? 'ShortAnswer';

  /// Web documents store choices as `{ ChoiceID, ChoiceText }`
  /// (see `SurveyAnswerForm.jsx`).
  static String choiceId(Object? choice) =>
      choice is Map ? (choice['ChoiceID'] ?? '').toString() : choice.toString();

  static String choiceText(Object? choice) => choice is Map
      ? (choice['ChoiceText'] ?? choice['Label'] ?? '').toString()
      : choice.toString();

  /// Flattens one stored `Answer` into text a resident can read back.
  ///
  /// Mirrors `getRespondentAnswers` in `src/api/surveysLocal.js`: a rating shows
  /// its value out of `RatingMax`, everything else shows `AnswerText`. A blank
  /// `AnswerText` on a multiple choice question falls back to resolving
  /// `ChoiceID`, so a response written without a label still renders.
  ///
  /// Returns an empty string when the resident left the question blank, which
  /// the UI presents as "Not answered".
  static String answerDisplayValue(
    Map<String, dynamic> question,
    Map<String, dynamic> answer,
  ) {
    final type = questionType(question);
    final text = (answer['AnswerText'] as String?)?.trim() ?? '';

    if (type == 'Rating') {
      final rating = (answer['RatingValue'] as num?)?.toStringAsFixed(0);
      if (rating != null) {
        return '$rating of ${(question['RatingMax'] as num?)?.toInt() ?? 5}';
      }
      return text;
    }

    if (text.isNotEmpty) return text;

    final id = (answer['ChoiceID'] as String?) ?? '';
    if (type == 'MultipleChoice' && id.isNotEmpty) {
      final choices = question['Choices'];
      if (choices is List) {
        for (final c in choices) {
          if (choiceId(c) == id) return choiceText(c);
        }
      }
      // Fall back to the raw id so the answer is never silently dropped.
      return id;
    }
    return '';
  }

  /// One [Answer] per answered question, matching the web client's shape.
  Future<RepoResult> submit({
    required String surveyId,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      if ((await _answeredSurveyIds()).contains(surveyId)) {
        return const RepoResult(
          success: false,
          message: 'You have already submitted a response for this survey.',
        );
      }

      final surveyDoc = await _db.collection(_surveys).doc(surveyId).get();
      if (!surveyDoc.exists ||
          !isWithinWindow(surveyDoc.data()!, todayString())) {
        return const RepoResult(
          success: false,
          message: 'This survey is no longer accepting responses.',
        );
      }

      final byQuestion = <String, Map<String, dynamic>>{
        for (final a in answers) a['QuestionID'] as String: a,
      };

      for (final q in await questions(surveyId)) {
        final qid = q['QuestionID'] as String;
        final a = byQuestion[qid];
        final text = a?['AnswerText'] as String?;
        if (text != null && text.length > 1000) {
          return const RepoResult(
            success: false,
            message: 'One of your answers is too long (max 1000 characters).',
          );
        }
        if (q['IsRequired'] == true) {
          final hasAnswer =
              (text != null && text.trim().isNotEmpty) ||
              (a?['ChoiceID'] as String?)?.isNotEmpty == true ||
              a?['RatingValue'] != null;
          if (!hasAnswer) {
            return const RepoResult(
              success: false,
              message: 'Please answer all required questions.',
            );
          }
        }
      }

      // Read the resident's own name fields rather than splitting a display
      // string, matching `residentSurveysLocal.js`.
      final residentDoc = await _db
          .collection(_residents)
          .doc(residentId)
          .get();
      final resident = residentDoc.data();

      await _db.collection(_responses).add({
        'SurveyID': surveyId,
        'ResidentID': residentId,
        'FirstName': resident?['FirstName'] as String? ?? '',
        'LastName': resident?['LastName'] as String? ?? '',
        'SubmittedAt': todayString(),
        'Answers': [
          for (final a in answers)
            {
              'QuestionID': a['QuestionID'],
              'AnswerText': a['AnswerText'],
              'ChoiceID': a['ChoiceID'],
              'RatingValue': a['RatingValue'],
            },
        ],
      });

      // Audit write is best effort and never blocks the submission.
      unawaited(_writeAudit(surveyId));

      return const RepoResult(success: true);
    } catch (_) {
      return const RepoResult(
        success: false,
        message: "Couldn't submit your response. Check your connection.",
      );
    }
  }

  Future<void> _writeAudit(String surveyId) async {
    try {
      await _db.collection(_logs).add({
        'ActorType': 'Resident',
        'ActorID': residentId,
        'Action': 'Submitted survey response',
        'TargetType': 'Survey',
        'TargetID': surveyId,
        'Timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // A failed audit write must not fail the resident's submission.
    }
  }
}

/// One question with the answer the resident gave, flattened for reading.
///
/// The same shape backs both the pre-submit review sheet and the read-only
/// response screen, so the resident sees the same wording either way.
class SubmittedAnswer {
  const SubmittedAnswer({
    required this.questionId,
    required this.questionText,
    required this.type,
    required this.value,
  });

  final String questionId;
  final String questionText;
  final String type;

  /// Human-readable answer. Empty when the resident left it blank.
  final String value;

  bool get isBlank => value.isEmpty;
}
