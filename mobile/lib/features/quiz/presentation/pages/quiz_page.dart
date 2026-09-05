import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/theme/app_radius.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class QuizPage extends ConsumerWidget {
  const QuizPage({required this.moduleId, required this.lessonId, super.key});

  final String moduleId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiz = ref.watch(quizForLessonProvider(lessonId));
    return quiz.when(
      loading: () => const Scaffold(body: ContentLoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ContentErrorView(
          message: networkErrorMessage(error),
          onRetry: () => ref.invalidate(quizForLessonProvider(lessonId)),
        ),
      ),
      data: (quiz) => quiz.questions.isEmpty
          ? const Scaffold(
              body: EmptyContentView(
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
      return _QuizResultPage(quiz: quiz, session: session);
    }

    final question = quiz.questions[session.currentQuestionIndex];
    final isLastQuestion =
        session.currentQuestionIndex == quiz.questions.length - 1;

    return Scaffold(
      appBar: AppBar(title: Text(quiz.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.readingContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Soru ${session.currentQuestionIndex + 1} / '
                        '${quiz.questions.length}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      Text(
                        '%${(((session.currentQuestionIndex + 1) / quiz.questions.length) * 100).round()}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(
                    value:
                        (session.currentQuestionIndex + 1) /
                        quiz.questions.length,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                question.prompt,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          for (final (index, option)
                              in question.options.indexed)
                            _QuizOptionCard(
                              index: index,
                              text: option.text,
                              isSelected: session.selectedOptionId == option.id,
                              onTap: () => ref
                                  .read(
                                    quizControllerProvider(selection).notifier,
                                  )
                                  .selectOption(option.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed:
                        session.selectedOptionId == null || session.isSubmitting
                        ? null
                        : () => ref
                              .read(quizControllerProvider(selection).notifier)
                              .submitAndContinue(),
                    child: session.isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isLastQuestion ? 'Quizi Bitir' : 'Sonraki Soru'),
                  ),
                  if (session.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      session.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizOptionCard extends StatelessWidget {
  const _QuizOptionCard({
    required this.index,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final int index;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: isSelected ? colorScheme.secondaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.55),
          width: isSelected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Text(
                  String.fromCharCode(65 + index),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizResultPage extends StatelessWidget {
  const _QuizResultPage({required this.quiz, required this.session});

  final Quiz quiz;
  final QuizSessionState session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Sonucu')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.compactContentWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 112,
                            height: 112,
                            child: CircularProgressIndicator(
                              value: session.successPercentage / 100,
                              strokeWidth: AppSpacing.xs,
                            ),
                          ),
                          Text(
                            '%${session.successPercentage}',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        quiz.title,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: _ResultValue(
                              icon: Icons.check_circle_outline_rounded,
                              text: 'Doğru: ${session.correctCount}',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _ResultValue(
                              icon: Icons.cancel_outlined,
                              text: 'Yanlış: ${session.incorrectCount}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ResultValue(
                        icon: Icons.insights_rounded,
                        text: 'Başarı: %${session.successPercentage}',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.tonalIcon(
                        onPressed: context.pop,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Derse Dön'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultValue extends StatelessWidget {
  const _ResultValue({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
