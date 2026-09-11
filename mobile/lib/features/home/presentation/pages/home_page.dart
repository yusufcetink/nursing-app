import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/home/presentation/providers/learning_home_provider.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(educationModulesProvider);
    final user = ref.watch(authControllerProvider).value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recommended = ref.watch(recommendedModuleProvider);
    final activity = ref.watch(learningActivityProvider);
    return Scaffold(
      body: modules.when(
        loading: () => const SafeArea(child: ContentLoadingView()),
        error: (error, _) => SafeArea(
          child: ContentErrorView(
            message: networkErrorMessage(error),
            onRetry: () => ref.invalidate(educationModulesProvider),
          ),
        ),
        data: (modules) => LearningBody(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BrandWordmark(),
                IconButton.filledTonal(
                  tooltip: 'Profilini aç',
                  onPressed: () => context.goNamed(AppRoutes.profile),
                  icon: const Icon(Icons.person_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              user == null || user.firstName.trim().isEmpty
                  ? 'İyi ki geldin'
                  : 'İyi ki geldin, ${user.firstName}',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Bugün kendine\nbir şey kat.',
              style: theme.textTheme.displaySmall,
            ),
            const SizedBox(height: 24),
            if (recommended != null) _ContinueLearning(module: recommended),
            if (modules.isEmpty)
              const EmptyContentView(
                message: 'Henüz yayınlanmış eğitim modülü bulunmuyor.',
              ),
            const SizedBox(height: 16),
            activity.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => ListTile(
                title: const Text('İlerlemen yüklenemedi'),
                trailing: IconButton(
                  tooltip: 'Yeniden dene',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(progressControllerProvider),
                ),
              ),
              data: (activity) => LearningPanel(
                color: scheme.secondaryContainer,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      color: scheme.onSecondaryContainer,
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bugünkü emeğin',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activity.todayCount == 0
                                ? 'Bir ders, yeni bir bakış.'
                                : '${activity.todayCount} ders tamamladın. Kendinle gurur duy.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Öğrenme rotan', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Eğitim Modülleri',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            for (final (index, module) in modules.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ModuleRow(module: module, index: index),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContinueLearning extends ConsumerWidget {
  const _ContinueLearning({required this.module});
  final EducationModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = ref.watch(moduleProgressProvider(module));
    final progressState = ref.watch(progressControllerProvider);
    return LearningPanel(
      color: scheme.inverseSurface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: LearningPill(
              progress > 0 && progress < 1
                  ? 'KALDIĞIN YERDEN'
                  : progress >= 1
                  ? 'BİLGİNİ TAZELE'
                  : 'YOLCULUĞUN BURADA BAŞLASIN',
              color: scheme.onInverseSurface.withValues(alpha: .12),
              foreground: scheme.onInverseSurface,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: Text(
                    module.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.onInverseSurface,
                    ),
                  ),
                ),
                if (constraints.maxWidth >= 280 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.2)
                  const LearningArt(size: 96),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            progressState.hasError
                ? 'İlerleme bilgisi alınamadı'
                : progressState.isLoading
                ? 'İlerlemen yükleniyor…'
                : '${(progress * module.lessonCount).round()} / ${module.lessonCount} ders tamamlandı',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onInverseSurface,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progressState.isLoading ? null : progress.clamp(0, 1),
            color: scheme.inversePrimary,
            backgroundColor: scheme.onInverseSurface.withValues(alpha: .14),
            semanticsLabel: 'Modül ilerlemesi',
          ),
          const SizedBox(height: 16),
          LearningAction(
            label: progress >= 1
                ? 'Yeniden keşfet'
                : progress > 0
                ? 'Öğrenmeye devam et'
                : 'Öğrenmeye başla',
            onPressed: () => context.pushNamed(
              AppRoutes.educationModule,
              pathParameters: {AppRoutes.moduleIdParameter: module.id},
            ),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onInverseSurface,
              foregroundColor: scheme.inverseSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleRow extends ConsumerWidget {
  const _ModuleRow({required this.module, required this.index});
  final EducationModule module;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final progress = ref.watch(moduleProgressProvider(module));
    final hasProgress = ref.watch(progressControllerProvider).hasValue;
    return Material(
      key: Key('home_module_${module.id}'),
      color: index.isEven ? scheme.primaryContainer : scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          AppRoutes.educationModule,
          pathParameters: {AppRoutes.moduleIdParameter: module.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              LearningArt(
                artwork: const [
                  LearningArtwork.book,
                  LearningArtwork.shield,
                  LearningArtwork.heart,
                ][index % 3],
                size: 48,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${module.lessonCount} ders',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (hasProgress)
                          Text(
                            '%${(progress * 100).round()} tamamlandı',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
