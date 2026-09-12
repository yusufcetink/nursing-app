import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/features/quiz/presentation/providers/quiz_next_lesson_provider.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';

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
    final nextLesson = ref.watch(
      quizNextLessonProvider((moduleId: moduleId, lessonId: currentLessonId)),
    );
    void goHome() => context.goNamed(AppRoutes.home);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goHome();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Sonucu'),
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
          children: [
            LearningPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: .85, end: 1),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 650),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: const LearningArtScene(
                        artwork: LearningArtwork.medal,
                        size: 180,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: LearningPill(
                      'BİR ADIM DAHA İLERİ',
                      icon: Icons.auto_awesome,
                      color: scheme.surface,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    session.successPercentage >= 80
                        ? 'Güzel iş!'
                        : 'Her deneme bir adım.',
                    style: theme.textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bir quiz daha tamamladın.\nBilgin adım adım büyüyor.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    label: 'Başarı oranı yüzde ${session.successPercentage}',
                    excludeSemantics: true,
                    child: Text(
                      '%${session.successPercentage}',
                      style: theme.textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text(
                    'başarı oranı',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  LearningProgress(
                    value: session.successPercentage / 100,
                    label: 'Başarı oranı',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LearningStat(
                    value: '${session.correctCount}',
                    label: 'Doğru',
                  ),
                ),
                Expanded(
                  child: LearningStat(
                    value: '${session.incorrectCount}',
                    label: 'Tekrar',
                  ),
                ),
                Expanded(
                  child: LearningStat(
                    value:
                        '${session.result?.totalQuestionCount ?? quiz.questions.length}',
                    label: 'Toplam soru',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LearningPanel(
              color: scheme.secondaryContainer,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    quiz.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.incorrectCount == 0
                        ? 'Tüm soruları doğru yanıtladın. Bu emeğinle gurur duy.'
                        : '${session.incorrectCount} soruda gelişme alanın var. Her deneme öğrendiklerini pekiştirmek için bir fırsat.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ],
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
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
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
                    TextButton(
                      onPressed: () {
                        // Reset the learning branch before opening history so
                        // neither back nor the Home tab can restore this quiz.
                        goHome();
                        context.pushNamed(AppRoutes.quizHistory);
                      },
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
