import 'package:flutter/material.dart';
import 'package:asli_app/shared/widgets/learning_motion.dart';

/// Feedback for server-confirmed answers and final results.
class QuizFeedbackPanel extends StatelessWidget {
  const QuizFeedbackPanel({
    required this.correct,
    required this.title,
    required this.message,
    super.key,
  });
  final bool correct;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = correct
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;
    return LearningReveal(
      duration: correct ? LearningMotion.correct : LearningMotion.incorrect,
      bounce: correct,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: correct ? scheme.tertiaryContainer : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              correct
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              color: foreground,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
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
