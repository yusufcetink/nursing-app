import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/features/quiz/presentation/providers/quiz_next_lesson_provider.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';
import 'package:asli_app/features/quiz/presentation/widgets/quiz_result_hero.dart';

class QuizResultPage extends ConsumerWidget {
  const QuizResultPage({
    required this.moduleId,
    required this.currentLessonId,
    required this.quiz,
    required this.session,
    super.key,
  });
  final String moduleId;
  final String currentLessonId;
  final Quiz quiz;
  final QuizSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firstName = ref.watch(authControllerProvider).value?.firstName.trim();
    final module = ref.watch(educationModuleProvider(moduleId)).value;
    final nextLesson = ref.watch(
      quizNextLessonProvider((moduleId: moduleId, lessonId: currentLessonId)),
    );
    void goHome() => context.goNamed(AppRoutes.home);
    void goHistory() {
      // Clear the learning branch so history cannot restore this result.
      goHome();
      context.pushNamed(AppRoutes.quizHistory);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goHome();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Sonucu'),
          centerTitle: true,
          titleTextStyle: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: 'Ana Sayfaya Dön',
              onPressed: goHome,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        body: LearningBody(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          children: [
            Text(
              (module?.title ?? quiz.title).toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            QuizResultHero(
              key: ValueKey(session.result?.attemptId),
              percentage: session.result == null
                  ? null
                  : session.successPercentage,
            ),
            const SizedBox(height: 8),
            Text(
              session.result == null
                  ? 'Sonuç yüklenemedi'
                  : session.successPercentage >= 80
                  ? 'Güzel ilerliyorsun${firstName == null || firstName.isEmpty ? "!" : ", $firstName."}'
                  : 'Her deneme bir adım.',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              session.result == null
                  ? 'Sonucunu quiz geçmişinden kontrol edebilirsin.'
                  : '${session.correctCount} doğru yanıt. Her adım bilgini güçlendiriyor.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              label: session.result == null
                  ? 'Sonuç bilgisi alınamadı'
                  : 'Başarı oranı yüzde ${session.successPercentage}. ${session.correctCount} doğru, ${session.incorrectCount} yanlış.',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ResultStat(
                        value: session.result == null
                            ? '—'
                            : '${session.correctCount}',
                        label: 'Doğru',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ResultStat(
                        value: session.result == null
                            ? '—'
                            : '${session.incorrectCount}',
                        label: 'Yanlış',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ResultStat(
                        value: session.result == null
                            ? '—'
                            : '${session.result!.totalQuestionCount}',
                        label: 'Soru',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (session.incorrectCount > 0)
              _ResultReviewCard(
                incorrectCount: session.incorrectCount,
                onHistory: goHistory,
              ),
            nextLesson.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (lesson) => lesson == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: .35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SIRADAKİ DERS',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lesson.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.readingContentWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nextLesson.when(
                      skipLoadingOnRefresh: false,
                      loading: () => const LearningAction(
                        label: 'Sıradaki adım yükleniyor…',
                        busy: true,
                        onPressed: null,
                      ),
                      error: (_, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sıradaki ders yüklenemedi.',
                            textAlign: TextAlign.center,
                          ),
                          LearningAction(
                            label: 'Yeniden Dene',
                            onPressed: () => ref.invalidate(
                              educationModuleProvider(moduleId),
                            ),
                          ),
                          TextButton(
                            onPressed: goHome,
                            child: const Text('Ana Sayfaya Dön'),
                          ),
                        ],
                      ),
                      data: (lesson) => LearningAction(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        label: lesson == null
                            ? 'Ana Sayfaya Dön'
                            : 'Sıradaki Derse Geç',
                        onPressed: lesson == null
                            ? goHome
                            : () => context.goNamed(
                                AppRoutes.lesson,
                                pathParameters: {
                                  AppRoutes.moduleIdParameter: moduleId,
                                  AppRoutes.lessonIdParameter: lesson.id,
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (nextLesson.asData?.value != null)
                      TextButton(
                        onPressed: goHome,
                        child: const Text('Ana Sayfaya Dön'),
                      ),
                    if (session.incorrectCount == 0)
                      TextButton(
                        onPressed: goHistory,
                        child: const Text('Quiz geçmişim'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.headlineLarge
            ?.copyWith(fontWeight: FontWeight.w800),
        textAlign: TextAlign.center,
      ),
      Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _ResultReviewCard extends StatelessWidget {
  const _ResultReviewCard({
    required this.incorrectCount,
    required this.onHistory,
  });
  final int incorrectCount;
  final VoidCallback onHistory;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final icon = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: scheme.secondaryFixedDim.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.menu_book_outlined,
        size: 34,
        color: scheme.secondaryFixedDim,
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$incorrectCount soruyu birlikte pekiştirelim.',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sonuçlarını inceleyebilirsin.',
          style: theme.textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: onHistory,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          child: const Text('Quiz geçmişim'),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? scheme.surface
            : scheme.secondaryContainer.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: theme.brightness == Brightness.dark ? .4 : 0,
          ),
        ),
      ),
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [icon, const SizedBox(height: 12), text],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(width: 16),
                Expanded(child: text),
              ],
            ),
    );
  }
}
