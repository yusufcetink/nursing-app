import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';
import 'package:asli_app/shared/widgets/module_cover.dart';
import 'package:asli_app/shared/widgets/learning_progress_display.dart';

/// Shared module identity and progress surface; navigation stays with the page.
class EducationModuleCard extends ConsumerWidget {
  const EducationModuleCard({
    required this.module,
    required this.onOpen,
    this.hero = false,
    super.key,
  });
  final EducationModule module;
  final VoidCallback onOpen;
  final bool hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(progressControllerProvider);
    final progress = ref.watch(moduleProgressProvider(module)).clamp(0.0, 1.0);
    final known = state.hasValue && !state.hasError;
    final completed = known && module.lessonCount > 0 && progress >= 1;
    final count = (progress * module.lessonCount).round();
    final status = !known
        ? state.hasError
              ? 'İlerleme yüklenemedi'
              : 'İlerleme yükleniyor…'
        : module.lessonCount == 0
        ? 'Dersler hazırlanıyor'
        : completed
        ? 'Tamamlandı'
        : progress > 0
        ? 'Devam ediyor'
        : 'Başlanmadı';
    final label = completed
        ? 'Yeniden incele'
        : hero
        ? progress > 0
              ? 'Öğrenmeye devam et'
              : 'Öğrenmeye başla'
        : progress > 0
        ? 'Devam et'
        : 'Başla';
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ModuleCover(
                  title: module.title,
                  aspectRatio: hero ? 2.15 : 1.5,
                ),
                if (hero)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LearningPill(
                        completed
                            ? 'BİLGİNİ TAZELE'
                            : known && progress == 0
                            ? 'İLK ADIMIN'
                            : 'KALDIĞIN YERDEN',
                        color: scheme.primary,
                        foreground: scheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final title = Text(
                        module.title,
                        style: theme.textTheme.headlineSmall,
                      );
                      if (!hero ||
                          !known ||
                          module.lessonCount == 0 ||
                          constraints.maxWidth < 290 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                        return title;
                      }
                      return Row(
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: 10),
                          LearningProgressRing(
                            value: progress,
                            label: 'Modül ilerlemesi',
                            centerLabel: '$count / ${module.lessonCount}',
                            total: module.lessonCount,
                            size: 76,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    module.description,
                    maxLines:
                        hero && MediaQuery.textScalerOf(context).scale(1) <= 1.3
                        ? 2
                        : null,
                    overflow:
                        hero && MediaQuery.textScalerOf(context).scale(1) <= 1.3
                        ? TextOverflow.ellipsis
                        : null,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hero && known && module.lessonCount > 0)
                    Text(
                      '$count / ${module.lessonCount} ders tamamlandı',
                      style: theme.textTheme.bodySmall,
                    )
                  else ...[
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          completed
                              ? Icons.check_circle_outline
                              : Icons.auto_stories_outlined,
                          color: completed ? scheme.tertiary : scheme.primary,
                          size: 20,
                        ),
                        if (known)
                          Text(
                            '$count / ${module.lessonCount} ders',
                            style: theme.textTheme.labelLarge,
                          ),
                        Text(
                          status,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: completed
                                ? scheme.tertiary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LearningSegments(
                      value: known ? progress : null,
                      total: module.lessonCount,
                      label: '${module.title} ilerlemesi',
                    ),
                  ],
                  const SizedBox(height: 18),
                  LearningAction(
                    label: module.lessonCount == 0 ? 'Modülü incele' : label,
                    onPressed: onOpen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
