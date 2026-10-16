import 'package:flutter_test/flutter_test.dart';

import 'package:barangay_health_portal/services/survey_repository.dart';

/// The display rules that let a resident read their own answers back.
///
/// These are pure functions on purpose: the resident screens around them build
/// a real `SurveyRepository`, which reaches `FirebaseFirestore.instance` in its
/// constructor and so cannot be pumped in a widget test. Static members are
/// callable without an instance, so the rules stay covered here.
void main() {
  group('questionType', () {
    test('reads the stored type', () {
      expect(SurveyRepository.questionType({'Type': 'Rating'}), 'Rating');
      expect(SurveyRepository.questionType({'Type': 'YesNo'}), 'YesNo');
    });

    test('falls back to free text when the type is missing', () {
      expect(SurveyRepository.questionType({}), 'ShortAnswer');
      expect(SurveyRepository.questionType({'Type': null}), 'ShortAnswer');
    });

    test('passes an unrecognised type through untouched', () {
      expect(SurveyRepository.questionType({'Type': 'Nonsense'}), 'Nonsense');
    });
  });

  group('choice helpers', () {
    test('reads the stored choice shape', () {
      final choice = {'ChoiceID': 'c1', 'ChoiceText': 'Very satisfied'};
      expect(SurveyRepository.choiceId(choice), 'c1');
      expect(SurveyRepository.choiceText(choice), 'Very satisfied');
    });

    test('accepts a legacy label key', () {
      expect(SurveyRepository.choiceText({'Label': 'Legacy'}), 'Legacy');
    });

    test('accepts a bare string choice', () {
      expect(SurveyRepository.choiceId('c2'), 'c2');
      expect(SurveyRepository.choiceText('c2'), 'c2');
    });
  });

  group('answerDisplayValue', () {
    test('shows a rating out of its maximum', () {
      expect(
        SurveyRepository.answerDisplayValue(
          {'Type': 'Rating', 'RatingMax': 5},
          {'RatingValue': 4.0},
        ),
        '4 of 5',
      );
    });

    test('respects a non-default rating maximum', () {
      expect(
        SurveyRepository.answerDisplayValue(
          {'Type': 'Rating', 'RatingMax': 10},
          {'RatingValue': 7.0},
        ),
        '7 of 10',
      );
    });

    test('defaults the rating maximum to 5 when the question omits it', () {
      expect(
        SurveyRepository.answerDisplayValue(
          {'Type': 'Rating'},
          {'RatingValue': 2.0},
        ),
        '2 of 5',
      );
    });

    test('falls back to AnswerText when a rating has no RatingValue', () {
      expect(
        SurveyRepository.answerDisplayValue(
          {'Type': 'Rating'},
          {'RatingValue': null, 'AnswerText': '4'},
        ),
        '4',
      );
    });

    test('shows a yes/no answer as its label', () {
      expect(
        SurveyRepository.answerDisplayValue(
          {'Type': 'YesNo'},
          {'AnswerText': 'Yes'},
        ),
        'Yes',
      );
    });

    test('shows multiple choice as its label', () {
      expect(
        SurveyRepository.answerDisplayValue(
          {
            'Type': 'MultipleChoice',
            'Choices': [
              {'ChoiceID': 'c0', 'ChoiceText': 'Rarely'},
              {'ChoiceID': 'c1', 'ChoiceText': 'Often'},
            ],
          },
          {'AnswerText': 'Often', 'ChoiceID': 'c1'},
        ),
        'Often',
      );
    });

    test('resolves ChoiceID when a response stored no label', () {
      expect(
        SurveyRepository.answerDisplayValue(
          {
            'Type': 'MultipleChoice',
            'Choices': [
              {'ChoiceID': 'c0', 'ChoiceText': 'Rarely'},
              {'ChoiceID': 'c1', 'ChoiceText': 'Often'},
            ],
          },
          {'AnswerText': null, 'ChoiceID': 'c1'},
        ),
        'Often',
      );
    });

    test('shows the raw choice id when no choice matches it', () {
      expect(
        SurveyRepository.answerDisplayValue(
          {'Type': 'MultipleChoice', 'Choices': []},
          {'AnswerText': null, 'ChoiceID': 'c9'},
        ),
        'c9',
      );
    });

    test('preserves newlines in an essay answer', () {
      expect(
        SurveyRepository.answerDisplayValue(
          {'Type': 'ShortAnswer'},
          {'AnswerText': 'First line.\nSecond line.'},
        ),
        'First line.\nSecond line.',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        SurveyRepository.answerDisplayValue(
          {'Type': 'ShortAnswer'},
          {'AnswerText': '  padded  '},
        ),
        'padded',
      );
    });

    test('reports a skipped question as blank', () {
      for (final type in const [
        'ShortAnswer',
        'YesNo',
        'MultipleChoice',
        'Rating',
      ]) {
        expect(
          SurveyRepository.answerDisplayValue(
            {'Type': type},
            {'AnswerText': null, 'ChoiceID': null, 'RatingValue': null},
          ),
          isEmpty,
          reason: 'a blank $type answer should render as not answered',
        );
      }
    });

    test('treats a whitespace-only essay answer as blank', () {
      expect(
        SurveyRepository.answerDisplayValue(
          {'Type': 'ShortAnswer'},
          {'AnswerText': '   '},
        ),
        isEmpty,
      );
    });

    test('treats an untyped question as free text', () {
      expect(
        SurveyRepository.answerDisplayValue({}, {
          'AnswerText': 'typed as an essay',
        }),
        'typed as an essay',
      );
    });
  });
}
