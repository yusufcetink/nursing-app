import 'package:flutter/material.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';
import 'package:asli_app/shared/widgets/learning_motion.dart';

enum LessonStepStatus { completed, current, next, locked, unknown }

class LearningPathStep extends StatelessWidget {
  const LearningPathStep({
    required this.lesson,
    required this.index,
    required this.status,
    required this.last,
    required this.onOpen,
    this.lockReason,
    super.key,
  });
  final Lesson lesson;
  final int index;
  final LessonStepStatus status;
  final bool last;
  final VoidCallback onOpen;
  final String? lockReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final current = status == LessonStepStatus.current;
    final completed = status == LessonStepStatus.completed;
    final locked = status == LessonStepStatus.locked;
    final label = switch (status) {
      LessonStepStatus.completed => 'Tamamlandı',
      LessonStepStatus.current => 'ŞİMDİ',
      LessonStepStatus.next => 'Sırada',
      LessonStepStatus.locked => lockReason ?? 'Önceki dersin ardından',
      LessonStepStatus.unknown => 'İlerleme bekleniyor',
    };
    final accent = completed ? scheme.tertiary : scheme.primary;
    final title = Text(
      lesson.title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
    );
    final statusText = Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: completed || current ? accent : scheme.onSurfaceVariant,
        fontWeight: completed || current ? FontWeight.w600 : FontWeight.w400,
      ),
    );
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 44,
          child: CustomPaint(
            painter: _PathConnector(
              color: completed ? scheme.tertiary : scheme.outline,
              dashed: !completed,
              last: last,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  const SizedBox(height: 13),
                  ExcludeSemantics(
                    child: AnimatedContainer(
                      duration: LearningMotion.duration(
                        context,
                        LearningMotion.correct,
                      ),
                      width: current
                          ? 44
                          : completed
                          ? 28
                          : 36,
                      height: current
                          ? 44
                          : completed
                          ? 28
                          : 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: completed
                            ? scheme.tertiary
                            : current
                            ? scheme.primary
                            : theme.scaffoldBackgroundColor,
                        border: Border.all(
                          color: completed || current
                              ? accent
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: Icon(
                        completed
                            ? Icons.check_rounded
                            : current
                            ? Icons.play_arrow_rounded
                            : locked
                            ? Icons.lock_outline_rounded
                            : Icons.play_arrow_outlined,
                        size: current ? 28 : 20,
                        color: completed
                            ? scheme.onTertiary
                            : current
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Material(
                  color: current
                      ? Color.alphaBlend(
                          scheme.primary.withValues(alpha: .08),
                          scheme.surface,
                        )
                      : scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: current
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: .45),
                      width: current ? 1.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: locked ? null : onOpen,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!largeText)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${index + 1}'.padLeft(2, '0'),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: current
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                      fontWeight: current
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (!largeText) const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (largeText) ...[
                                      Text(
                                        'Ders ${index + 1}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    if (current) ...[
                                      statusText,
                                      const SizedBox(height: 4),
                                    ],
                                    title,
                                    const SizedBox(height: 4),
                                    if (current)
                                      Text(
                                        'Sıradaki adımın hazır.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      )
                                    else
                                      statusText,
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (current) ...[
                            const SizedBox(height: 12),
                            LearningAction(
                              label: 'Derse devam et',
                              onPressed: onOpen,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Drawn behind the nodes, so long titles can grow without breaking the path.
class _PathConnector extends CustomPainter {
  const _PathConnector({
    required this.color,
    required this.dashed,
    required this.last,
  });
  final Color color;
  final bool dashed;
  final bool last;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .65)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final bottom = last ? 26.0 : size.height;
    if (dashed) {
      for (double y = 0; y < bottom; y += 10) {
        canvas.drawLine(
          Offset(22, y),
          Offset(22, (y + 5).clamp(0, bottom)),
          paint,
        );
      }
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(22, 0)
          ..cubicTo(30, bottom * .35, 14, bottom * .65, 22, bottom),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PathConnector old) =>
      old.color != color || old.dashed != dashed || old.last != last;
}
