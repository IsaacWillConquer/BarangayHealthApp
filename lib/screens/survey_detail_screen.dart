import 'package:flutter/material.dart';

import '../services/survey_repository.dart';
import '../theme.dart';
import '../utils/motion.dart';
import '../widgets/answer_summary.dart';
import '../widgets/common.dart';
import 'surveys_screen.dart';

/// Renders one survey's questions and submits a response.
///
/// Question types mirror `src/components/SurveyAnswerForm.jsx` and
/// `src/data/surveyConstants.js`: MultipleChoice, YesNo, Rating, ShortAnswer.
/// Answers are written in the same shape the web client uses, with `AnswerText`
/// populated for multiple choice so staff tallies keep working.
class SurveyDetailScreen extends StatefulWidget {
  const SurveyDetailScreen({
    super.key,
    required this.surveys,
    required this.survey,
  });

  final SurveyRepository surveys;
  final QuerySurvey survey;

  @override
  State<SurveyDetailScreen> createState() => _SurveyDetailScreenState();
}

class _SurveyDetailScreenState extends State<SurveyDetailScreen> {
  final _textControllers = <String, TextEditingController>{};
  final _choice = <String, String?>{};
  final _rating = <String, double>{};
  final _yesNo = <String, String>{};

  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final questions = await widget.surveys.questions(widget.survey.id);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load the survey.";
        _loading = false;
      });
    }
  }

  TextEditingController _controllerFor(String questionId) =>
      _textControllers.putIfAbsent(questionId, TextEditingController.new);

  Future<void> _review() async {
    if (_busy) return;

    // Check required fields up front so the resident gets every missing answer
    // at once, instead of one server round-trip per question.
    final missing = _questions
        .where((q) => q['IsRequired'] == true && !_hasAnswer(q))
        .map((q) => q['QuestionText'])
        .toList();
    if (missing.isNotEmpty) {
      setState(() => _error = 'Please answer all required questions.');
      showFlash(context, 'Missing: ${missing.join(', ')}', error: true);
      return;
    }

    // Submission is one-shot: `activeSurveys` filters out anything already
    // answered, so there is no edit path afterwards. Review first.
    final answers = _collectAnswers();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      builder: (_) => _AnswerReviewSheet(rows: _reviewRows(answers)),
    );
    if (confirmed == true && mounted) await _confirmAndSubmit(answers);
  }

  /// Builds the answers payload.
  ///
  /// The review sheet renders this exact list, so what the resident confirms is
  /// what gets written rather than a second, separately-derived summary.
  List<Map<String, dynamic>> _collectAnswers() {
    final answers = <Map<String, dynamic>>[];
    for (final q in _questions) {
      final id = q['QuestionID'] as String;
      final type = SurveyRepository.questionType(q);
      String? text;
      String? choiceId;
      double? rating;

      if (type == 'MultipleChoice') {
        choiceId = _choice[id];
        text = _choiceLabel(q, choiceId);
      } else if (type == 'Rating') {
        rating = _rating[id];
        text = rating?.toStringAsFixed(0);
      } else if (type == 'YesNo') {
        text = _yesNo[id];
      } else {
        text = _textControllers[id]?.text.trim();
      }

      answers.add({
        'QuestionID': id,
        'AnswerText': (text == null || text.isEmpty) ? null : text,
        'ChoiceID': choiceId,
        'RatingValue': rating,
      });
    }
    return answers;
  }

  /// Pairs each question with the answer about to be written, formatted through
  /// the same helper the read-only response screen uses.
  List<SubmittedAnswer> _reviewRows(List<Map<String, dynamic>> answers) {
    final rows = <SubmittedAnswer>[];
    for (var i = 0; i < _questions.length && i < answers.length; i++) {
      final q = _questions[i];
      rows.add(
        SubmittedAnswer(
          questionId: q['QuestionID'] as String,
          questionText: (q['QuestionText'] as String?) ?? '',
          type: SurveyRepository.questionType(q),
          value: SurveyRepository.answerDisplayValue(q, answers[i]),
        ),
      );
    }
    return rows;
  }

  Future<void> _confirmAndSubmit(List<Map<String, dynamic>> answers) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await widget.surveys.submit(
      surveyId: widget.survey.id,
      answers: answers,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      setState(() => _error = result.message);
      showFlash(context, result.message ?? 'Could not submit.', error: true);
      return;
    }
    showFlash(context, 'Response submitted. Thank you.');
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
  }

  /// A question with no or an unrecognised `Type` is treated as free text, the
  /// same way an unknown type falls through to the default answer field.
  static String _typeOf(Map<String, dynamic> q) =>
      SurveyRepository.questionType(q);

  bool _hasAnswer(Map<String, dynamic> q) {
    final id = q['QuestionID'] as String;
    switch (_typeOf(q)) {
      case 'MultipleChoice':
        return (_choice[id] ?? '').isNotEmpty;
      case 'Rating':
        return _rating.containsKey(id);
      case 'YesNo':
        return (_yesNo[id] ?? '').isNotEmpty;
      default:
        return (_textControllers[id]?.text.trim() ?? '').isNotEmpty;
    }
  }

  static String _choiceLabel(Map<String, dynamic> q, String? choiceId) {
    if (choiceId == null || choiceId.isEmpty) return '';
    final choices = q['Choices'];
    if (choices is! List) return choiceId;
    for (final c in choices) {
      if (SurveyRepository.choiceId(c) == choiceId) {
        return SurveyRepository.choiceText(c);
      }
    }
    return choiceId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.survey.title, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: context.colors.accent),
            )
          : motionEntrance(
              context,
              _error != null && _questions.isEmpty
                  ? EmptyState(_error!, icon: Icons.cloud_off_outlined)
                  : ListView(
                      padding: EdgeInsets.all(16),
                      children: [
                        if (widget.survey.description.isNotEmpty) ...[
                          Text(
                            widget.survey.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.colors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        for (var i = 0; i < _questions.length; i++)
                          _questionCard(i),
                        const SizedBox(height: 12),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.errorFg,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton(
                          onPressed: _busy ? null : _review,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Submit response'),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
            ),
    );
  }

  Widget _questionCard(int index) {
    final q = _questions[index];
    final id = q['QuestionID'] as String;
    final required = q['IsRequired'] == true;
    final type = _typeOf(q);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${q['QuestionText'] ?? ''}${required ? ' *' : ''}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            switch (type) {
              // The web offers a single free-text type, `ShortAnswer`, rendered
              // as a multi-line textarea (`SurveyAnswerForm.jsx`). A phone needs
              // the same affordance, so both map to this field.
              'ShortAnswer' => TextField(
                controller: _controllerFor(id),
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Type your answer',
                  counterText: '',
                ),
              ),
              'MultipleChoice' => _multipleChoice(q, id),
              'Rating' => _ratingField(q, id),
              'YesNo' => _yesNoField(id),
              _ => TextField(
                controller: _controllerFor(id),
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Type your answer',
                  counterText: '',
                ),
              ),
            },
          ],
        ),
      ),
    );
  }

  Widget _multipleChoice(Map<String, dynamic> q, String id) {
    final choices = q['Choices'];
    final items = choices is List ? choices : const [];
    if (items.isEmpty) {
      return Text(
        'No choices are available for this question.',
        style: TextStyle(fontSize: 13, color: context.colors.textMuted),
      );
    }
    return RadioGroup<String>(
      groupValue: _choice[id] ?? '',
      onChanged: (v) => setState(() => _choice[id] = v),
      child: Column(
        children: [
          for (final c in items)
            RadioListTile<String>(
              value: _choiceId(c),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_choiceText(c), style: const TextStyle(fontSize: 14)),
            ),
        ],
      ),
    );
  }

  /// Web documents store choices as `{ ChoiceID, ChoiceText }`
  /// (see `SurveyAnswerForm.jsx`).
  static String _choiceId(Object? choice) => SurveyRepository.choiceId(choice);

  static String _choiceText(Object? choice) =>
      SurveyRepository.choiceText(choice);

  /// `YesNo` has no `Choices` of its own; the web client offers a fixed
  /// Yes/No pair and stores the label in `AnswerText`
  /// (see `SurveyAnswerForm.jsx`).
  Widget _yesNoField(String id) {
    return RadioGroup<String>(
      groupValue: _yesNo[id] ?? '',
      onChanged: (v) => setState(() => _yesNo[id] = v ?? ''),
      child: Row(
        children: [
          for (final v in const ['Yes', 'No']) ...[
            Radio<String>(value: v, activeColor: context.colors.accent),
            Text(v, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 20),
          ],
        ],
      ),
    );
  }

  Widget _ratingField(Map<String, dynamic> q, String id) {
    final min = (q['RatingMin'] as num?)?.toDouble() ?? 1;
    final max = (q['RatingMax'] as num?)?.toDouble() ?? 5;
    final step = (q['RatingStep'] as num?)?.toDouble() ?? 1;
    if (step <= 0) {
      return Text(
        'This rating question is misconfigured.',
        style: TextStyle(fontSize: 13, color: context.colors.errorFg),
      );
    }
    final current = _rating[id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Slider(
          value: current ?? min,
          min: min,
          max: max,
          divisions: ((max - min) / step).round().clamp(1, 100),
          activeColor: context.colors.accent,
          label: (current ?? min).toStringAsFixed(0),
          onChanged: (v) => setState(() => _rating[id] = v),
        ),
        Text(
          'Selected: ${(current ?? min).toStringAsFixed(0)}',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

/// Lists the answers about to be submitted so the resident can check them.
///
/// The title and the buttons stay pinned while the answers scroll, which
/// matters once a survey carries a few long essay responses.
class _AnswerReviewSheet extends StatelessWidget {
  const _AnswerReviewSheet({required this.rows});

  final List<SubmittedAnswer> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review your answers',
                    style: TextStyle(
                      fontFamily: AppTheme.headingFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You can only submit once. Check everything before sending.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => AnswerSummaryRow(
                  question: rows[i].questionText,
                  value: rows[i].value,
                  leading: '${i + 1}',
                ),
              ),
            ),
            Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Back to edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Submit response'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
