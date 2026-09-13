import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/education/presentation/widgets/education_module_card.dart';
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
    void openModule(EducationModule module) => context.pushNamed(
      AppRoutes.educationModule,
      pathParameters: {AppRoutes.moduleIdParameter: module.id},
    );
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Aslı App', style: theme.textTheme.titleLarge),
                ),
                IconButton.filledTonal(
                  tooltip: 'Profilini aç',
                  onPressed: () => context.goNamed(AppRoutes.profile),
                  icon: const Icon(Icons.person_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              user == null || user.firstName.trim().isEmpty
                  ? 'Merhaba'
                  : 'Merhaba, ${user.firstName}',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text('Bugün bir\nadım daha.', style: theme.textTheme.displaySmall),
            const SizedBox(height: 20),
            if (recommended != null)
              EducationModuleCard(
                module: recommended,
                hero: true,
                onOpen: () => openModule(recommended),
              ),
            if (modules.isEmpty)
              const EmptyContentView(
                message: 'Henüz yayınlanmış eğitim modülü bulunmuyor.',
              ),
            const SizedBox(height: 20),
            const Divider(),
            activity.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Günlük aktivite yükleniyor…'),
              ),
              error: (error, _) => ListTile(
                title: const Text('İlerlemen yüklenemedi'),
                trailing: IconButton(
                  tooltip: 'Yeniden dene',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(progressControllerProvider),
                ),
              ),
              data: (activity) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.wb_sunny_outlined,
                        color: scheme.onSecondaryContainer,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bugünkü emeğin',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activity.todayCount == 0
                                ? 'Bir ders, yeni bir bakış.'
                                : '${activity.todayCount} ders tamamladın.',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 24),
            Text('Eğitim Modülleri', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Öğrenme rotanı keşfet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            for (final module in modules)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: EducationModuleCard(
                  key: Key('home_module_${module.id}'),
                  module: module,
                  onOpen: () => openModule(module),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
