import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/features/quiz/presentation/pages/quiz_result_page.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';

class QuizPage extends ConsumerWidget {
  const QuizPage({required this.moduleId, required this.lessonId, super.key});
  final String moduleId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(quizForLessonProvider(lessonId))
        .when(
          loading: () =>
              Scaffold(appBar: AppBar(), body: const ContentLoadingView()),
          error: (error, _) => Scaffold(
            appBar: AppBar(),
            body: ContentErrorView(
              message: networkErrorMessage(error),
              onRetry: () => ref.invalidate(quizForLessonProvider(lessonId)),
            ),
          ),
          data: (quiz) => quiz.questions.isEmpty
              ? Scaffold(
                  appBar: AppBar(),
                  body: const EmptyContentView(
                    message: 'Bu quiz için henüz soru bulunmuyor.',
                  ),
                )
              : _QuizContent(moduleId: moduleId, quiz: quiz),
        );
  }
}

class _QuizContent extends ConsumerWidget {
  const _QuizContent({required this.moduleId, required this.quiz});
  final String moduleId;
  final Quiz quiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = (moduleId: moduleId, lessonId: quiz.lessonId);
    final session = ref.watch(quizControllerProvider(selection));
    if (session.isCompleted) {
      return QuizResultPage(quiz: quiz, session: session);
    }
    final question = quiz.questions[session.currentQuestionIndex];
    final isLast = session.currentQuestionIndex == quiz.questions.length - 1;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini quiz'),
        actions: const [
          LearningPill('Süresiz', icon: Icons.all_inclusive_rounded),
          SizedBox(width: 24),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.readingContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    key: ValueKey(question.id),
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    children: [
                      LinearProgressIndicator(
                        value:
                            (session.currentQuestionIndex + 1) /
                            quiz.questions.length,
                        semanticsLabel: 'Soru ilerlemesi',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Soru ${session.currentQuestionIndex + 1} / ${quiz.questions.length}',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        quiz.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        question.prompt,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Bir yanıt seç.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (final (index, option) in question.options.indexed)
                        _QuizOption(
                          index: index,
                          text: option.text,
                          selected: session.selectedOptionId == option.id,
                          onTap: session.isSubmitting
                              ? null
                              : () => ref
                                    .read(
                                      quizControllerProvider(selection)
                                          .notifier,
                                    )
                                    .selectOption(option.id),
                        ),
                      const SizedBox(height: 8),
                      LearningPanel(
                        color: scheme.secondaryContainer,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.spa_outlined,
                              color: scheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Acele yok. Kendi ritminde ilerle.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (session.errorMessage != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            session.errorMessage!,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      LearningAction(
                        label: isLast ? 'Quizi Bitir' : 'Sonraki Soru',
                        busy: session.isSubmitting,
                        onPressed: session.selectedOptionId == null
                            ? null
                            : () => ref
                                  .read(
                                    quizControllerProvider(selection).notifier,
                                  )
                                  .submitAndContinue(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizOption extends StatelessWidget {
  const _QuizOption({
    required this.index,
    required this.text,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: selected,
        button: true,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected ? scheme.primaryContainer : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      String.fromCharCode(65 + index),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
