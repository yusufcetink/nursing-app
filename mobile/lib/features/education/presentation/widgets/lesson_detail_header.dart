import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/shared/widgets/learning_progress_display.dart';

class LessonDetailHeader extends ConsumerWidget {
  const LessonDetailHeader({required this.lesson, super.key});
  final Lesson lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final module = ref
        .watch(educationModuleProvider(lesson.educationModuleId))
        .value;
    final progressState = ref.watch(progressControllerProvider);
    final completed = ref.watch(lessonCompletedProvider(lesson.id));
    final known = progressState.hasValue && !progressState.hasError;
    final progress = module == null
        ? 0.0
        : ref.watch(moduleProgressProvider(module)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (module != null) ...[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                module.title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              Text(
                known
                    ? '${(progress * module.lessonCount).round()} / ${module.lessonCount} ders tamamlandı'
                    : progressState.hasError
                    ? 'İlerleme yüklenemedi'
                    : 'İlerleme yükleniyor…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LearningSegments(
            value: known ? progress : null,
            total: module.lessonCount,
            label: 'Modül ilerlemesi',
          ),
          const SizedBox(height: 24),
        ],
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'DERS ${lesson.order.toString().padLeft(2, '0')}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 19,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${lesson.estimatedDurationMinutes} dk',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          lesson.title,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -.9,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          lesson.description,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        if (completed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Tamamlandı',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.tertiary,
              ),
            ),
          ),
      ],
    );
  }
}
