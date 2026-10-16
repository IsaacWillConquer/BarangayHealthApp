import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barangay_health_portal/services/theme_prefs.dart';
import 'package:barangay_health_portal/theme.dart';

/// Relative luminance per WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio, 1.0 to 21.0.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('palette integrity', () {
    test('light and dark differ on every slot', () {
      final l = AppTheme.lightColors;
      final d = AppTheme.darkColors;

      expect(l.surface, isNot(d.surface));
      expect(l.surfaceElevated, isNot(d.surfaceElevated));
      expect(l.scaffoldBg, isNot(d.scaffoldBg));
      expect(l.border, isNot(d.border));
      expect(l.textPrimary, isNot(d.textPrimary));
      expect(l.textSecondary, isNot(d.textSecondary));
      expect(l.textMuted, isNot(d.textMuted));
      expect(l.appBarBg, isNot(d.appBarBg));
      expect(l.flashBg, isNot(d.flashBg));
      expect(l.accent, isNot(d.accent));
      expect(l.accentText, isNot(d.accentText));
      expect(l.errorBg, isNot(d.errorBg));
      expect(l.errorFg, isNot(d.errorFg));
      expect(l.errorBorder, isNot(d.errorBorder));
      expect(l.successBg, isNot(d.successBg));
      expect(l.successFg, isNot(d.successFg));
      expect(l.successBorder, isNot(d.successBorder));
      expect(l.warningBg, isNot(d.warningBg));
      expect(l.warningFg, isNot(d.warningFg));
      expect(l.warningBorder, isNot(d.warningBorder));
      expect(l.neutralBg, isNot(d.neutralBg));
      expect(l.neutralFg, isNot(d.neutralFg));
    });

    test('dark mode keeps the intended polarity', () {
      final d = AppTheme.darkColors;
      final l = AppTheme.lightColors;

      // Text must be brighter than the surfaces it sits on.
      expect(_luminance(d.textPrimary), greaterThan(_luminance(d.surface)));
      expect(_luminance(d.textSecondary), greaterThan(_luminance(d.surface)));
      expect(_luminance(d.textMuted), greaterThan(_luminance(d.surface)));

      // Cards lift off the scaffold in both modes.
      expect(_luminance(d.surfaceElevated), greaterThan(_luminance(d.surface)));
      expect(_luminance(d.surface), greaterThan(_luminance(d.scaffoldBg)));

      // In light mode text is darker than its surface, and a white card sits
      // above an off-white scaffold.
      expect(_luminance(l.textPrimary), lessThan(_luminance(l.surface)));
      expect(
        _luminance(l.surfaceElevated),
        greaterThan(_luminance(l.scaffoldBg)),
      );
    });

    test('body text meets WCAG AA on every surface it is used on', () {
      for (final entry in {
        'light': AppTheme.lightColors,
        'dark': AppTheme.darkColors,
      }.entries) {
        final c = entry.value;
        final mode = entry.key;

        for (final surface in {
          'scaffoldBg': c.scaffoldBg,
          'surface': c.surface,
          'surfaceElevated': c.surfaceElevated,
        }.entries) {
          for (final fg in {
            'textPrimary': c.textPrimary,
            'textSecondary': c.textSecondary,
            'textMuted': c.textMuted,
          }.entries) {
            final ratio = _contrast(fg.value, surface.value);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  '$mode ${fg.key} on ${surface.key} is only ${ratio.toStringAsFixed(2)}:1',
            );
          }
        }
      }
    });

    test('status badge and banner text meets WCAG AA on its own fill', () {
      for (final entry in {
        'light': AppTheme.lightColors,
        'dark': AppTheme.darkColors,
      }.entries) {
        final c = entry.value;
        final mode = entry.key;

        final pairs = {
          'error': (c.errorBg, c.errorFg),
          'success': (c.successBg, c.successFg),
          'warning': (c.warningBg, c.warningFg),
          'neutral': (c.neutralBg, c.neutralFg),
        };

        pairs.forEach((name, pair) {
          final ratio = _contrast(pair.$2, pair.$1);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$mode $name badge is only ${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });

    test('status fills stay distinguishable from the page behind them', () {
      for (final entry in {
        'light': AppTheme.lightColors,
        'dark': AppTheme.darkColors,
      }.entries) {
        final c = entry.value;
        final mode = entry.key;

        // A badge whose fill matches the card behind it reads as broken.
        for (final pair in {
          'error': c.errorBg,
          'success': c.successBg,
          'warning': c.warningBg,
          'neutral': c.neutralBg,
        }.entries) {
          final ratio = _contrast(pair.value, c.surface);
          expect(
            ratio,
            greaterThan(1.05),
            reason: '$mode ${pair.key} fill blends into the card',
          );
        }
      }
    });

    test('button text stays legible on the emerald fill', () {
      // FilledButton paints onPrimary over primary; primary is emerald in both
      // modes so this pair is checked once.
      final ratio = _contrast(Colors.white, AppTheme.emerald700);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('theme exposes its colours through the AppColors extension', () {
      for (final brightness in Brightness.values) {
        final theme = AppTheme.build(brightness: brightness);
        final extension = theme.extension<AppColors>();
        expect(extension, isNotNull);
        expect(
          extension,
          brightness == Brightness.dark
              ? AppTheme.darkColors
              : AppTheme.lightColors,
        );
      }
    });
  });

  group('dark theme wiring', () {
    testWidgets('app bar title is readable in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          darkTheme: AppTheme.build(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          home: Scaffold(
            appBar: AppBar(title: const Text('Surveys')),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      // The colour lives in the theme, not on the widget instance.
      final bg = AppBarTheme.of(
        tester.element(find.byType(AppBar)),
      ).backgroundColor!;
      expect(_contrast(Colors.white, bg), greaterThanOrEqualTo(4.5));
      expect(
        _luminance(bg),
        lessThan(0.05),
        reason: 'dark app bar is not dark',
      );
    });

    testWidgets('context.colors resolves the active brightness', (
      tester,
    ) async {
      late AppColors seen;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          darkTheme: AppTheme.build(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              seen = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen, same(AppTheme.darkColors));
    });

    testWidgets('themeMode.system follows the platform brightness', (
      tester,
    ) async {
      late AppColors seen;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          darkTheme: AppTheme.build(brightness: Brightness.dark),
          themeMode: ThemeMode.system,
          home: Builder(
            builder: (context) {
              seen = context.colors;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      await tester.pumpAndSettle();

      expect(seen, same(AppTheme.darkColors));
    });
  });

  group('theme mode cycling', () {
    test('next walks system to light to dark and back', () {
      expect(ThemePrefs.next(ThemeMode.system), ThemeMode.light);
      expect(ThemePrefs.next(ThemeMode.light), ThemeMode.dark);
      expect(ThemePrefs.next(ThemeMode.dark), ThemeMode.system);
    });
  });
}
