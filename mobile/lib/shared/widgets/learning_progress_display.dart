import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:asli_app/shared/widgets/learning_motion.dart';

class LearningSegments extends StatelessWidget {
  const LearningSegments({
    required this.value,
    required this.total,
    required this.label,
    this.duration = LearningMotion.progress,
    this.initialValue = 0,
    super.key,
  });
  final double? value;
  final int total;
  final String label;
  final Duration duration;
  final double initialValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      value: value == null
          ? 'İlerleme bilinmiyor'
          : '%${(value! * 100).round()}',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(
            begin: initialValue.clamp(0, 1),
            end: value?.clamp(0, 1) ?? 0,
          ),
          duration: LearningMotion.duration(context, duration),
          curve: Curves.easeOutCubic,
          builder: (context, animated, _) => SizedBox(
            height: 12,
            child: CustomPaint(
              painter: _SegmentsPainter(
                value: animated,
                count: total > 0 && total <= 12 ? total : 1,
                color: value == 1 ? scheme.tertiary : scheme.primary,
                track: scheme.outlineVariant,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class LearningProgressRing extends StatelessWidget {
  const LearningProgressRing({
    required this.value,
    required this.label,
    this.total = 10,
    this.centerLabel,
    this.size = 232,
    this.duration = LearningMotion.progress,
    super.key,
  });
  final double? value;
  final int total;
  final String label;
  final String? centerLabel;
  final double size;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Semantics(
      label: label,
      value:
          centerLabel ??
          (value == null ? 'Bilinmiyor' : '%${(value! * 100).round()}'),
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value?.clamp(0, 1) ?? 0),
          duration: LearningMotion.duration(context, duration),
          curve: Curves.easeOutCubic,
          builder: (context, animated, _) {
            final text = Text(
              centerLabel ??
                  (value == null ? '—' : '%${(animated * 100).round()}'),
              style: size < 150
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.displayMedium,
              textAlign: TextAlign.center,
            );
            final ring = SizedBox.square(
              dimension: size,
              child: CustomPaint(
                painter: _RingPainter(
                  value: animated,
                  count: total > 0 && total <= 12 ? total : 1,
                  color: value == 1 ? scheme.tertiary : scheme.primary,
                  track: scheme.outlineVariant,
                ),
                child: Center(
                  child: largeText
                      ? Icon(
                          Icons.auto_stories_rounded,
                          color: scheme.primary,
                          size: size * .25,
                        )
                      : Padding(
                          padding: EdgeInsets.all(size * .18),
                          child: text,
                        ),
                ),
              ),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ring,
                if (largeText) ...[const SizedBox(height: 8), text],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SegmentsPainter extends CustomPainter {
  const _SegmentsPainter({
    required this.value,
    required this.count,
    required this.color,
    required this.track,
  });
  final double value;
  final int count;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = count == 1 ? 0.0 : 5.0;
    final width = (size.width - gap * (count - 1)) / count;
    for (var i = 0; i < count; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (width + gap), 0, width, size.height),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, Paint()..color = track);
      final fill = (value * count - i).clamp(0.0, 1.0);
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(i * (width + gap), 0, width * fill, size.height),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SegmentsPainter oldDelegate) =>
      value != oldDelegate.value ||
      count != oldDelegate.count ||
      color != oldDelegate.color ||
      track != oldDelegate.track;
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.count,
    required this.color,
    required this.track,
  });
  final double value;
  final int count;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * .065;
    final rect = (Offset.zero & size).deflate(stroke);
    final gap = count == 1 ? 0.0 : .09;
    final sweep = math.pi * 2 / count - gap;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < count; i++) {
      final start = -math.pi / 2 + i * math.pi * 2 / count + gap / 2;
      canvas.drawArc(rect, start, sweep, false, paint..color = track);
      final fill = (value * count - i).clamp(0.0, 1.0);
      if (fill > 0) {
        canvas.drawArc(rect, start, sweep * fill, false, paint..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      value != oldDelegate.value ||
      count != oldDelegate.count ||
      color != oldDelegate.color ||
      track != oldDelegate.track;
}
