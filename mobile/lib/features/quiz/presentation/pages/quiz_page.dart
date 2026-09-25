import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/features/quiz/presentation/pages/quiz_result_page.dart';

import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';
import 'package:asli_app/shared/widgets/learning_motion.dart';

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
      return QuizResultPage(
        moduleId: moduleId,
        currentLessonId: quiz.lessonId,
        quiz: quiz,
        session: session,
      );
    }
    final question = quiz.questions[session.currentQuestionIndex];
    final isLast = session.currentQuestionIndex == quiz.questions.length - 1;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini quiz'),
        titleTextStyle: theme.textTheme.headlineSmall,
        actions: [
          if (!largeText)
            const LearningPill('Süresiz', icon: Icons.all_inclusive_rounded),
          if (!largeText) const SizedBox(width: 24),
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    children: [
                      if (largeText)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: LearningPill(
                              'Süresiz',
                              icon: Icons.all_inclusive_rounded,
                            ),
                          ),
                        ),
                      LinearProgressIndicator(
                        value: session.answers.length / quiz.questions.length,
                        semanticsLabel: 'Soru ilerlemesi',
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(20),
                        color: scheme.primary,
                        backgroundColor: scheme.outlineVariant.withValues(
                          alpha: .55,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text(
                            'Soru ${session.currentQuestionIndex + 1} / ${quiz.questions.length}',
                            style: theme.textTheme.labelLarge,
                          ),
                          Text(
                            quiz.title,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        question.prompt,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                          letterSpacing: -.7,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Bir yanıt seç.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (final (index, option) in question.options.indexed)
                        _QuizOption(
                          key: ValueKey('quiz_option_${option.id}'),
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        label: isLast
                            ? 'Cevabı Onayla ve Bitir'
                            : 'Cevabı Onayla',
                        busy: session.isSubmitting,
                        onPressed:
                            session.selectedOptionId == null ||
                                session.isSubmitting
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
    super.key,
  });
  final int index;
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  final bool correct = false;
  final bool incorrect = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedScale(
        scale: selected ? .99 : 1,
        duration: LearningMotion.duration(
          context,
          const Duration(milliseconds: 120),
        ),
        curve: Curves.easeOutCubic,
        child: Semantics(
          label: correct
              ? 'Doğru seçenek'
              : incorrect
              ? 'Yanlış yanıt'
              : null,
          selected: selected,
          button: true,
          inMutuallyExclusiveGroup: true,
          child: AnimatedContainer(
            duration: LearningMotion.duration(
              context,
              correct ? LearningMotion.correct : LearningMotion.incorrect,
            ),
            decoration: BoxDecoration(
              color: correct
                  ? scheme.tertiaryContainer
                  : incorrect
                  ? scheme.secondaryContainer
                  : selected
                  ? scheme.primaryContainer
                  : theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: correct
                    ? scheme.tertiary
                    : incorrect
                    ? scheme.secondary
                    : selected
                    ? scheme.primary
                    : scheme.outlineVariant,
                width: selected || correct ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? scheme.primary
                                  : Colors.transparent,
                              border: Border.all(
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                            child: Text(
                              String.fromCharCode(65 + index),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: selected
                                    ? scheme.onPrimary
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                          if (largeText) const Spacer(),
                          if (!largeText) const SizedBox(width: 14),
                          if (!largeText)
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
                          const SizedBox(width: 8),
                          Icon(
                            correct
                                ? Icons.check_circle_outline_rounded
                                : incorrect
                                ? Icons.cancel_outlined
                                : selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: correct
                                ? scheme.onTertiaryContainer
                                : incorrect
                                ? scheme.onSecondaryContainer
                                : selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ],
                      ),
                      if (largeText) ...[
                        const SizedBox(height: 12),
                        Text(
                          text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
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
