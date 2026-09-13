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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  height: 10,
                  width: 2,
                  color: index == 0
                      ? Colors.transparent
                      : scheme.outlineVariant,
                ),
                ExcludeSemantics(
                  child: AnimatedContainer(
                    duration: LearningMotion.duration(
                      context,
                      LearningMotion.correct,
                    ),
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed
                          ? scheme.tertiaryContainer
                          : current
                          ? scheme.primary
                          : scheme.surface,
                      border: Border.all(
                        color: completed || current
                            ? accent
                            : scheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: completed || current || locked
                        ? Icon(
                            completed
                                ? Icons.check_rounded
                                : locked
                                ? Icons.lock_outline
                                : Icons.play_arrow_rounded,
                            color: current
                                ? scheme.onPrimary
                                : completed
                                ? scheme.onTertiaryContainer
                                : scheme.onSurfaceVariant,
                            size: 22,
                          )
                        : Text(
                            '${index + 1}',
                            style: theme.textTheme.labelLarge,
                          ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: completed
                            ? scheme.tertiary
                            : scheme.outlineVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Material(
                color: current ? scheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: locked ? null : onOpen,
                  child: Padding(
                    padding: EdgeInsets.all(current ? 16 : 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: completed
                                ? scheme.tertiary
                                : current
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(lesson.title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          '${lesson.estimatedDurationMinutes} dk',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(height: 10),
                          Text(
                            lesson.description,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          LearningAction(
                            label: 'Derse devam et',
                            onPressed: onOpen,
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
    );
  }
}
