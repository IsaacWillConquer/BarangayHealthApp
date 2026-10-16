import 'package:flutter/material.dart';

/// Reference timings, matched to the web portal's transitions so both clients
/// feel like the same product.
const kFadeDuration = Duration(milliseconds: 150);
const kRiseDuration = Duration(milliseconds: 180);
const kModalDuration = Duration(milliseconds: 160);

const _easeOut = Curves.easeOut;

/// Single definition of a subtle vertical offset, in logical pixels.
const _rise = 12.0;

/// Shared so every entrance widget reuses one tween instance. A fresh `Tween`
/// on each build would compare unequal by identity and restart the animation
/// on every parent rebuild.
final Tween<double> _entranceTween = Tween<double>(begin: 0, end: 1);

/// Whether the platform or the user has asked for less motion.
///
/// Every helper in this file funnels through here, so there is exactly one
/// place that honours the preference. This reads `disableAnimations`, which
/// reflects Android's "Remove animations" accessibility setting.
bool reducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// [duration], or nothing at all when motion is reduced.
Duration motionDuration(BuildContext context, Duration duration) =>
    reducedMotion(context) ? Duration.zero : duration;

/// Fades and lifts content in as it arrives, skipping the animation entirely
/// when motion is reduced.
///
/// Intended for content that replaces a spinner or appears with its screen.
Widget motionEntrance(BuildContext context, Widget child) {
  if (reducedMotion(context)) return child;
  return TweenAnimationBuilder<double>(
    tween: _entranceTween,
    duration: kRiseDuration,
    curve: _easeOut,
    child: child,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, _rise * (1 - t)),
        child: child,
      ),
    ),
  );
}

/// Page transition that fades and lifts the incoming screen.
///
/// Extends [MaterialPageRoute] rather than using a bare `PageRouteBuilder` so
/// the platform's predictive back gesture keeps working on Android; only
/// `buildTransitions` is replaced.
///
/// Pass `animate: false` from [reducedMotion] to make navigation instant.
class FadeThroughRoute<T> extends MaterialPageRoute<T> {
  FadeThroughRoute({required super.builder, bool animate = true})
    : _animate = animate;

  final bool _animate;

  @override
  Duration get transitionDuration => _animate ? kModalDuration : Duration.zero;

  @override
  Duration get reverseTransitionDuration =>
      _animate ? kFadeDuration : Duration.zero;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!_animate) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: _easeOut,
      reverseCurve: Curves.easeIn,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
