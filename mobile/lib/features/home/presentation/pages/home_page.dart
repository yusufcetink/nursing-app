import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_radius.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(educationModulesProvider);

    return Scaffold(
      body: modules.when(
        loading: () => const SafeArea(child: ContentLoadingView()),
        error: (error, _) => SafeArea(
          child: ContentErrorView(
            message: networkErrorMessage(error),
            onRetry: () => ref.invalidate(educationModulesProvider),
          ),
        ),
        data: (modules) => modules.isEmpty
            ? const SafeArea(
                child: EmptyContentView(
                  message: 'Henüz yayınlanmış eğitim modülü bulunmuyor.',
                ),
              )
            : SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding =
                        constraints.maxWidth >= AppSpacing.wideScreenBreakpoint
                        ? AppSpacing.xl
                        : AppSpacing.md;

                    return SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppSpacing.maxContentWidth,
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              AppSpacing.lg,
                              horizontalPadding,
                              AppSpacing.section,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _HomeHeader(),
                                const SizedBox(height: AppSpacing.xl),
                                const _LearningHero(),
                                const SizedBox(height: AppSpacing.xl),
                                _SectionHeader(moduleCount: modules.length),
                                const SizedBox(height: AppSpacing.md),
                                for (final module in modules)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.md,
                                    ),
                                    child: _EducationModuleCard(
                                      module: module,
                                      progress: ref.watch(
                                        moduleProgressProvider(module),
                                      ),
                                      onTap: () => context.pushNamed(
                                        AppRoutes.educationModule,
                                        pathParameters: {
                                          AppRoutes.moduleIdParameter:
                                              module.id,
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: AppSpacing.section,
          height: AppSpacing.section,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Icon(
            Icons.local_hospital_outlined,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aslı App', style: Theme.of(context).textTheme.titleLarge),
              Text(
                'Hemşirelik öğrenme alanın',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LearningHero extends StatelessWidget {
  const _LearningHero();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ÖĞRENME ALANI',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Öğrenmeye devam et',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: colorScheme.onTertiaryContainer),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Bir eğitim modülü seç, derslerini tamamla ve bilgini ölç.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: colorScheme.onTertiaryContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: AppSpacing.xl,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.moduleCount});

  final int moduleCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Eğitim Modülleri',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$moduleCount modül',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

class _EducationModuleCard extends StatelessWidget {
  const _EducationModuleCard({
    required this.module,
    required this.progress,
    required this.onTap,
  });

  final EducationModule module;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progressPercent = (progress * 100).round();

    return Semantics(
      button: true,
      label: '${module.title} modülünü aç',
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.large),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: AppSpacing.section,
                      height: AppSpacing.section,
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Icon(
                        _moduleIcon(module.id),
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            module.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            module.description,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.menu_book_outlined,
                            size: AppSpacing.md,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text('${module.lessonCount} ders'),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '%$progressPercent tamamlandı',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(value: progress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _moduleIcon(String moduleId) {
    return switch (moduleId) {
      'nursing-fundamentals' => Icons.medical_services_outlined,
      'patient-safety' => Icons.health_and_safety_outlined,
      'clinical-assessment' => Icons.monitor_heart_outlined,
      _ => Icons.school_outlined,
    };
  }
}
