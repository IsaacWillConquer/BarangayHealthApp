import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barangay_health_portal/theme.dart';
import 'package:barangay_health_portal/widgets/answer_summary.dart';
import 'package:barangay_health_portal/widgets/common.dart';

/// The emulator is 411x914 dp, so that is what these render at.
const Size mediumPhone = Size(411, 914);

Widget _host(Widget child, ThemeMode mode) {
  return MaterialApp(
    theme: AppTheme.build(),
    darkTheme: AppTheme.build(brightness: Brightness.dark),
    themeMode: mode,
    home: Scaffold(body: child),
  );
}

void _atMediumPhone(WidgetTester tester) {
  tester.view.physicalSize = mediumPhone * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  for (final mode in ThemeMode.values) {
    final label = mode.name;

    group('layout in $label mode', () {
      // Login and the password gate are not covered here: both build an
      // AuthRepository that reaches FirebaseFirestore.instance in its
      // constructor, which needs a live app. They are checked on the device
      // instead, where the screens render against the real backend.

      testWidgets('every status badge renders in this mode', (tester) async {
        for (final status in [
          'Active',
          'Approved',
          'Pending',
          'Upcoming',
          'Rejected',
          'Closed',
          'Archived',
        ]) {
          await tester.pumpWidget(_host(StatusBadge(status), mode));
          await tester.pumpAndSettle();
          expect(find.text(status), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('long info values stay on screen', (tester) async {
        _atMediumPhone(tester);

        await tester.pumpWidget(
          _host(
            const Column(
              children: [
                InfoRow('Full name', 'Maria Reyes Santos Del Rosario Jr.'),
                InfoRow(
                  'Address',
                  '123 Mabini Street, Barangay Sta. Cruz, Antipolo City, Rizal',
                ),
                InfoRow('Civil status', ''),
              ],
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('answer summary shows a blank answer as not answered', (
        tester,
      ) async {
        _atMediumPhone(tester);

        await tester.pumpWidget(
          _host(
            const AnswerSummaryRow(
              question: 'Would you like a barangay health worker to follow up?',
              value: '',
              leading: '1',
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Not answered'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('answer summary shows a picked answer', (tester) async {
        _atMediumPhone(tester);

        await tester.pumpWidget(
          _host(
            const AnswerSummaryRow(
              question: 'How would you rate your visit?',
              value: '4 of 5',
              leading: '1',
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('4 of 5'), findsOneWidget);
        expect(find.text('Not answered'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('answer summary fits a max-length essay answer', (
        tester,
      ) async {
        _atMediumPhone(tester);

        // The field caps answers at 1000 characters, and the review sheet
        // renders them inside a scroll view. Reproduce both here so the test
        // reflects the real constraint rather than an unreachable one.
        const sentence = 'Recurring tension on the left side. ';
        final essay = sentence * (1000 ~/ sentence.length);

        await tester.pumpWidget(
          _host(
            SingleChildScrollView(
              child: AnswerSummaryRow(
                question: 'Describe any health concerns you want known.',
                value: essay,
                leading: '1',
              ),
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        expect(essay.length, lessThanOrEqualTo(1000));
        expect(find.byType(AnswerSummaryRow), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('answer summary fits an unbreakable long token', (
        tester,
      ) async {
        _atMediumPhone(tester);

        await tester.pumpWidget(
          _host(
            const AnswerSummaryRow(
              question: 'Which medicine are you taking?',
              value: 'Paracetamol500mg',
              leading: '1',
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('a stack of answer rows fits without overflow', (
        tester,
      ) async {
        _atMediumPhone(tester);

        await tester.pumpWidget(
          _host(
            const Column(
              children: [
                AnswerSummaryRow(
                  question: 'How would you rate your visit?',
                  value: '4 of 5',
                  leading: '1',
                ),
                AnswerSummaryRow(
                  question: 'Any concerns to report?',
                  value: 'Headaches in the evening, otherwise fine.',
                  leading: '2',
                ),
                AnswerSummaryRow(
                  question: 'Would you like a follow-up?',
                  value: '',
                  leading: '3',
                ),
              ],
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Not answered'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('info rows in a card share one left edge', (tester) async {
        _atMediumPhone(tester);

        // Mirrors the Edit profile Name card. The 20dp ListView padding matters:
        // it drops the row width under 340dp, which selects the stacked layout
        // where the ragged left edge showed up. In the wider side-by-side layout
        // `Expanded` already fills the width, so the bug cannot appear there.
        await tester.pumpWidget(
          _host(
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: const Column(
                      children: [
                        InfoRow('First name', 'Maria'),
                        InfoRow('Middle name', 'Reyes'),
                        InfoRow('Last name', 'Santos'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        final lefts = [
          tester.getTopLeft(find.text('First name')).dx,
          tester.getTopLeft(find.text('Middle name')).dx,
          tester.getTopLeft(find.text('Last name')).dx,
        ];
        expect(
          lefts.toSet().length,
          1,
          reason: 'labels must align, got $lefts',
        );

        final values = [
          tester.getTopLeft(find.text('Maria')).dx,
          tester.getTopLeft(find.text('Reyes')).dx,
          tester.getTopLeft(find.text('Santos')).dx,
        ];
        expect(
          values.toSet().length,
          1,
          reason: 'values must align, got $values',
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('info rows with empty and long values still align', (
        tester,
      ) async {
        _atMediumPhone(tester);

        await tester.pumpWidget(
          _host(
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: const Column(
                      children: [
                        InfoRow('Suffix', ''),
                        InfoRow(
                          'Address',
                          '789 Mabini Street, Barangay Poblacion, Antipolo City',
                        ),
                        InfoRow('Email', 'maria.santos@example.com'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        final lefts = [
          tester.getTopLeft(find.text('Suffix')).dx,
          tester.getTopLeft(find.text('Address')).dx,
          tester.getTopLeft(find.text('Email')).dx,
        ];
        expect(
          lefts.toSet().length,
          1,
          reason: 'labels must align, got $lefts',
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('a wide card still lays rows out side by side', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _host(
            const SizedBox(
              width: 600,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      InfoRow('First name', 'Maria'),
                      InfoRow('Middle name', 'Reyes Santos Del Rosario Jr.'),
                      InfoRow('Last name', 'Santos'),
                    ],
                  ),
                ),
              ),
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        // Above the 340dp threshold the label sits in a fixed column, so the
        // values line up with each other.
        final values = [
          tester.getTopLeft(find.text('Maria')).dx,
          tester.getTopLeft(find.text('Reyes Santos Del Rosario Jr.')).dx,
          tester.getTopLeft(find.text('Santos')).dx,
        ];
        expect(
          values.toSet().length,
          1,
          reason: 'values must align, got $values',
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('empty state fits without overflow', (tester) async {
        _atMediumPhone(tester);

        await tester.pumpWidget(
          _host(
            const EmptyState('No surveys are open right now. Check back soon.'),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('field labels and section headers fit', (tester) async {
        _atMediumPhone(tester);

        await tester.pumpWidget(
          _host(
            const Column(
              children: [
                SectionHeader('Personal details'),
                FieldLabel('Resident Number or Email'),
                FieldLabel('Middle name', optional: true),
              ],
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('optional'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
