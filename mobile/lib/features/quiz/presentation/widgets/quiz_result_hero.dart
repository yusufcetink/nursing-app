import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:asli_app/shared/widgets/learning_motion.dart';

/// Ten visual segments represent percentage, independently of question count.
class QuizResultHero extends StatelessWidget {
  const QuizResultHero({required this.percentage, super.key});
  final int? percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final score = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              if (percentage != null)
                TextSpan(text: '%', style: theme.textTheme.headlineLarge),
              TextSpan(text: percentage == null ? '—' : '$percentage'),
            ],
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 58,
            fontWeight: FontWeight.w800,
            letterSpacing: -2,
          ),
        ),
        Text(
          'başarı oranı',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
    return Semantics(
      label: 'Başarı oranı',
      value: percentage == null ? 'Bilinmiyor' : 'yüzde $percentage',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final diameter = math.min(constraints.maxWidth * .64, 248.0);
            return Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: (percentage ?? 0).clamp(0, 100) / 100,
                  ),
                  duration: LearningMotion.duration(
                    context,
                    LearningMotion.progress,
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => SizedBox(
                    width: diameter,
                    height: diameter + 16,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        CustomPaint(
                          size: Size.square(diameter),
                          painter: _ResultRingPainter(
                            value: value,
                            scheme: scheme,
                          ),
                        ),
                        if (!largeText)
                          Positioned.fill(
                            bottom: 16,
                            child: Center(child: score),
                          ),
                        if (percentage != null)
                          Positioned(
                            bottom: 20,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: scheme.brightness == Brightness.dark
                                    ? scheme.onSurface
                                    : scheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: .4,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.shadow.withValues(alpha: .15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 32,
                                color: scheme.brightness == Brightness.dark
                                    ? scheme.surface
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (largeText) score,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ResultRingPainter extends CustomPainter {
  const _ResultRingPainter({required this.value, required this.scheme});
  final double value;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.width / 2 - 8;
    final inner = outer - size.width * .125;
    const corner = 4.0;
    Offset point(double radius, double angle) =>
        center + Offset(math.cos(angle), math.sin(angle)) * radius;
    // Fill counterclockwise from twelve o'clock, leaving the unfilled part at top right.
    for (var i = 0; i < 10; i++) {
      final start = -math.pi / 2 - (i + 1) * math.pi / 5 + .024;
      final end = start + math.pi / 5 - .048;
      final a = point(outer, start + corner / outer);
      final b = point(outer, end - corner / outer);
      final c = point(outer - corner, end);
      final d = point(inner + corner, end);
      final e = point(inner, end - corner / inner);
      final f = point(inner, start + corner / inner);
      final g = point(inner + corner, start);
      final h = point(outer - corner, start);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..arcToPoint(b, radius: Radius.circular(outer))
        ..quadraticBezierTo(
          point(outer, end).dx,
          point(outer, end).dy,
          c.dx,
          c.dy,
        )
        ..lineTo(d.dx, d.dy)
        ..quadraticBezierTo(
          point(inner, end).dx,
          point(inner, end).dy,
          e.dx,
          e.dy,
        )
        ..arcToPoint(f, radius: Radius.circular(inner), clockwise: false)
        ..quadraticBezierTo(
          point(inner, start).dx,
          point(inner, start).dy,
          g.dx,
          g.dy,
        )
        ..lineTo(h.dx, h.dy)
        ..quadraticBezierTo(
          point(outer, start).dx,
          point(outer, start).dy,
          a.dx,
          a.dy,
        )
        ..close();
      final fill = (value * 10 - i).clamp(0.0, 1.0);
      final active = i == (value * 10).ceil() - 1
          ? Color.lerp(scheme.tertiaryContainer, scheme.tertiary, .45)!
          : scheme.primary;
      final track = scheme.outlineVariant.withValues(alpha: .22);
      canvas.drawPath(path, Paint()..color = Color.lerp(track, active, fill)!);
      canvas.drawPath(
        path,
        Paint()
          ..color = scheme.outlineVariant.withValues(alpha: (1 - fill) * .65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outer + 7),
      math.pi * .39,
      math.pi * .22,
      false,
      Paint()
        ..color = scheme.secondaryFixedDim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ResultRingPainter oldDelegate) =>
      value != oldDelegate.value || scheme != oldDelegate.scheme;
}
