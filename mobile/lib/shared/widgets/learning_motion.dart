import 'package:flutter/material.dart';

abstract final class LearningMotion {
  static const correct = Duration(milliseconds: 320);
  static const incorrect = Duration(milliseconds: 180);
  static const lesson = Duration(milliseconds: 700);
  static const module = Duration(milliseconds: 850);
  static const progress = Duration(milliseconds: 700);

  static Duration duration(BuildContext context, Duration requested) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : requested;
}

/// Plays once when mounted, never loops or delays its child's actions.
class LearningReveal extends StatelessWidget {
  const LearningReveal({
    required this.child,
    required this.duration,
    this.bounce = false,
    super.key,
  });
  final Widget child;
  final Duration duration;
  final bool bounce;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: Transform.scale(
            scale: bounce ? .94 + .06 * Curves.easeOutBack.transform(value) : 1,
            child: child,
          ),
        ),
      ),
    );
  }
}
