import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/home/presentation/widgets/home_module_card.dart';
import 'package:asli_app/features/home/presentation/providers/learning_home_provider.dart';
import 'package:asli_app/features/leaderboard/presentation/compact_leaderboard_section.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _showAllModules = false;

  @override
  Widget build(BuildContext context) {
    final modules = ref.watch(educationModulesProvider);
    final user = ref.watch(authControllerProvider).value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recommended = ref.watch(recommendedModuleProvider);
    final activity = ref.watch(learningActivityProvider);
    final initials = [user?.firstName ?? '', user?.lastName ?? '']
        .where((name) => name.trim().isNotEmpty)
        .map((name) => name.trim().characters.first.toUpperCase())
        .join();
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'Aslı App',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Profilini aç',
                  onPressed: () => context.goNamed(AppRoutes.profile),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.brightness == Brightness.dark
                        ? const Color(0xff354c54)
                        : const Color(0xffcfdfd8),
                    foregroundColor: scheme.onSurface,
                  ),
                  icon: Text(
                    initials.isEmpty ? 'A' : initials,
                    style: theme.textTheme.labelLarge?.copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                user == null || user.firstName.trim().isEmpty
                    ? 'Merhaba'
                    : 'Merhaba, ${user.firstName}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Bugün bir\nadım daha.',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontSize: 38,
                  height: 1.04,
                  letterSpacing: -1.8,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (recommended != null)
              HomeModuleCard(
                module: recommended,
                hero: true,
                onOpen: () => openModule(recommended),
              ),
            if (modules.isEmpty)
              const EmptyContentView(
                message: 'Henüz yayınlanmış eğitim modülü bulunmuyor.',
              ),
            const SizedBox(height: 14),
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
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                child: Row(
                  children: [
                    const HomeActivitySun(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bugünkü emeğin',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activity.todayCount == 0
                                ? 'Bir ders, yeni bir bakış.'
                                : '${activity.todayCount} ders tamamladın',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const ExcludeSemantics(
                      child: Icon(Icons.chevron_right_rounded, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            const CompactLeaderboardSection(),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  'Eğitim modülleri',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 20,
                    letterSpacing: -.6,
                  ),
                ),
                if (modules.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        setState(() => _showAllModules = !_showAllModules),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _showAllModules ? 'Daha az göster' : 'Tümünü gör',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_showAllModules || largeText)
              for (final module in modules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: HomeModuleCard(
                    key: Key('home_module_${module.id}'),
                    module: module,
                    onOpen: () => openModule(module),
                  ),
                )
            else
              SingleChildScrollView(
                key: const Key('home_module_shelf'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final module in modules)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 224,
                          child: HomeModuleCard(
                            key: Key('home_module_${module.id}'),
                            module: module,
                            onOpen: () => openModule(module),
                          ),
                        ),
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
