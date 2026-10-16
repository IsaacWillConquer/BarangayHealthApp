import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barangay_health_portal/utils/motion.dart';

/// Pumps a MediaQuery whose reduced-motion flag is [disabled], runs [build]
/// beneath it so the helper can read that context, and returns the context.
Future<BuildContext> pumpMotionUnder(
  WidgetTester tester, {
  required bool disabled,
  required Widget Function(BuildContext context) build,
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disabled),
      child: Builder(
        builder: (context) {
          captured = context;
          return build(context);
        },
      ),
    ),
  );
  return captured;
}

/// Shorthand for the cases that only need a context.
Future<BuildContext> pumpUnder(WidgetTester tester, {required bool disabled}) =>
    pumpMotionUnder(tester, disabled: disabled, build: (_) => const SizedBox());

void main() {
  group('reducedMotion', () {
    testWidgets('is false when the platform allows animations', (tester) async {
      final context = await pumpUnder(tester, disabled: false);
      expect(reducedMotion(context), isFalse);
    });

    testWidgets('is true when the platform disables animations', (
      tester,
    ) async {
      final context = await pumpUnder(tester, disabled: true);
      expect(reducedMotion(context), isTrue);
    });
  });

  group('motionDuration', () {
    testWidgets('passes the duration through when motion is allowed', (
      tester,
    ) async {
      final context = await pumpUnder(tester, disabled: false);
      expect(motionDuration(context, kRiseDuration), kRiseDuration);
      expect(motionDuration(context, kFadeDuration), kFadeDuration);
    });

    testWidgets('collapses to zero when motion is reduced', (tester) async {
      final context = await pumpUnder(tester, disabled: true);
      expect(motionDuration(context, kRiseDuration), Duration.zero);
      expect(motionDuration(context, kFadeDuration), Duration.zero);
    });
  });

  group('reference timings', () {
    test('match the agreed values', () {
      expect(kFadeDuration, const Duration(milliseconds: 150));
      expect(kRiseDuration, const Duration(milliseconds: 180));
      expect(kModalDuration, const Duration(milliseconds: 160));
    });
  });

  group('motionEntrance', () {
    const target = ValueKey('target');
    Finder opacityAbove() =>
        find.ancestor(of: find.byKey(target), matching: find.byType(Opacity));

    testWidgets('adds no animated wrapper when motion is reduced', (
      tester,
    ) async {
      await pumpMotionUnder(
        tester,
        disabled: true,
        build: (context) =>
            motionEntrance(context, const SizedBox(key: target)),
      );

      // Returned by identity, so there is nothing to animate.
      expect(opacityAbove(), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('fades in from transparent when motion is allowed', (
      tester,
    ) async {
      await pumpMotionUnder(
        tester,
        disabled: false,
        build: (context) =>
            motionEntrance(context, const SizedBox(key: target)),
      );

      // First frame is fully transparent, so content never pops into place.
      expect(tester.widget<Opacity>(opacityAbove()).opacity, 0.0);

      await tester.pump(kRiseDuration);
      expect(tester.widget<Opacity>(opacityAbove()).opacity, 1.0);

      // One extra frame so the animation reports itself finished.
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('FadeThroughRoute', () {
    testWidgets('is instant and unwrapped when animate is false', (
      tester,
    ) async {
      final context = await pumpUnder(tester, disabled: true);

      final route = FadeThroughRoute<void>(
        animate: false,
        builder: (_) => const SizedBox(),
      );
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);

      const child = SizedBox();
      final built = route.buildTransitions(
        context,
        const AlwaysStoppedAnimation(1),
        const AlwaysStoppedAnimation(0),
        child,
      );
      // Returned by identity: nothing is wrapped, so nothing can fade.
      expect(identical(built, child), isTrue);
    });

    testWidgets('fades through when animate is true', (tester) async {
      final context = await pumpUnder(tester, disabled: false);

      final route = FadeThroughRoute<void>(builder: (_) => const SizedBox());
      expect(route.transitionDuration, kModalDuration);
      expect(route.reverseTransitionDuration, kFadeDuration);

      final built = route.buildTransitions(
        context,
        const AlwaysStoppedAnimation(1),
        const AlwaysStoppedAnimation(0),
        const SizedBox(),
      );
      expect(built, isA<FadeTransition>());
    });

    testWidgets('starts transparent at the beginning of the push', (
      tester,
    ) async {
      final context = await pumpUnder(tester, disabled: false);
      final route = FadeThroughRoute<void>(builder: (_) => const SizedBox());

      final fade =
          route.buildTransitions(
                context,
                const AlwaysStoppedAnimation(0),
                const AlwaysStoppedAnimation(0),
                const SizedBox(),
              )
              as FadeTransition;
      expect(fade.opacity.value, 0.0);

      final arrived =
          route.buildTransitions(
                context,
                const AlwaysStoppedAnimation(1),
                const AlwaysStoppedAnimation(0),
                const SizedBox(),
              )
              as FadeTransition;
      expect(arrived.opacity.value, 1.0);
    });
  });
}
