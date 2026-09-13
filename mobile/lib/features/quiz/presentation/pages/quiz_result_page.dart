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
import 'package:asli_app/shared/widgets/learning_progress_display.dart';
import 'package:asli_app/features/quiz/presentation/widgets/quiz_feedback_panel.dart';

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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              quiz.title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Center(
              child: LearningProgressRing(
                value: session.result == null
                    ? null
                    : session.successPercentage / 100,
                total:
                    session.result?.totalQuestionCount ?? quiz.questions.length,
                label: 'Başarı oranı',
              ),
            ),
            Text(
              'başarı oranı',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              session.result == null
                  ? 'Sonuç yüklenemedi'
                  : session.successPercentage >= 80
                  ? 'Güzel ilerliyorsun!'
                  : 'Her deneme bir adım.',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Bilgin adım adım büyüyor.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Semantics(
              liveRegion: true,
              label: session.result == null
                  ? 'Sonuç bilgisi alınamadı'
                  : 'Başarı oranı yüzde ${session.successPercentage}. ${session.correctCount} doğru, ${session.incorrectCount} yanlış.',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LearningStat(
                      value: session.result == null
                          ? '—'
                          : '${session.correctCount}',
                      label: 'Doğru',
                    ),
                  ),
                  Expanded(
                    child: LearningStat(
                      value: session.result == null
                          ? '—'
                          : '${session.incorrectCount}',
                      label: 'Yanlış',
                    ),
                  ),
                  Expanded(
                    child: LearningStat(
                      value: session.result == null
                          ? '—'
                          : '${session.result!.totalQuestionCount}',
                      label: 'Soru',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (session.correctCount > 0)
              QuizFeedbackPanel(
                key: ValueKey('correct_${session.result?.attemptId}'),
                correct: true,
                title: '${session.correctCount} doğru yanıt',
                message: 'Güzel yakaladın. Öğrendiklerin güçleniyor.',
              ),
            if (session.incorrectCount > 0) ...[
              const SizedBox(height: 12),
              QuizFeedbackPanel(
                key: ValueKey('incorrect_${session.result?.attemptId}'),
                correct: false,
                title: 'Birlikte pekiştirelim',
                message:
                    '${session.incorrectCount} yanlış yanıtın var. Ders içeriğini yeniden inceleyerek bilgini pekiştirebilirsin.',
              ),
            ],
            nextLesson.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (lesson) => lesson == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 18),
                          Text(
                            'SIRADAKİ DERS',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(lesson.title, style: theme.textTheme.titleLarge),
                        ],
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
