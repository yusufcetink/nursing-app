import 'package:flutter/material.dart';
import 'package:asli_app/features/education/presentation/providers/lesson_completion_provider.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';
import 'package:asli_app/shared/widgets/learning_motion.dart';
import 'package:asli_app/shared/widgets/learning_progress_display.dart';
import 'package:asli_app/shared/widgets/module_cover.dart';

class LessonCompletionSheet extends StatelessWidget {
  const LessonCompletionSheet({
    required this.lessonTitle,
    required this.completion,
    required this.actionLabel,
    super.key,
  });
  final String lessonTitle;
  final LessonCompletion? completion;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final moduleCompleted = completion?.moduleCompleted ?? false;
    final duration = moduleCompleted
        ? LearningMotion.module
        : LearningMotion.lesson;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Derse dön',
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            LearningReveal(
              duration: duration,
              bounce: true,
              child: moduleCompleted
                  ? Card(
                      color: scheme.tertiaryContainer,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ModuleCover(title: completion!.module.title),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.verified_outlined,
                                  size: 40,
                                  color: scheme.onTertiaryContainer,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  completion!.module.title,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: scheme.onTertiaryContainer,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${completion!.completed} / ${completion!.module.lessonCount} ders tamamlandı',
                                  style: TextStyle(
                                    color: scheme.onTertiaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          const LearningArt(size: 144),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.tertiaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 32,
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              header: true,
              child: Text(
                moduleCompleted ? 'Modül tamamlandı' : 'Ders tamamlandı',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.tertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              moduleCompleted
                  ? 'Bu yolculuğu tamamladın.'
                  : 'Bir adım daha attın.',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              moduleCompleted
                  ? 'Emeğin birikti. Öğrenmeye devam et.'
                  : '$lessonTitle dersini tamamladın.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (completion != null && completion!.module.lessonCount > 0) ...[
              const SizedBox(height: 22),
              LearningSegments(
                initialValue:
                    (completion!.completed - 1) /
                    completion!.module.lessonCount,
                value: completion!.completed / completion!.module.lessonCount,
                total: completion!.module.lessonCount,
                label: 'Modül ilerlemesi',
                duration: duration,
              ),
              if (!moduleCompleted) ...[
                const SizedBox(height: 10),
                Text(
                  '${completion!.completed} / ${completion!.module.lessonCount} ders tamamlandı',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
            const SizedBox(height: 24),
            LearningAction(
              label: actionLabel,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Dersi yeniden incele'),
            ),
          ],
        ),
      ),
    );
  }
}
