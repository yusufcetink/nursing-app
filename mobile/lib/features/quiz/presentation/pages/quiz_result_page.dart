import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';

class QuizResultPage extends StatelessWidget {
  const QuizResultPage({required this.quiz, required this.session, super.key});
  final Quiz quiz;
  final QuizSessionState session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Sonucu')),
      body: LearningBody(
        children: [
          const Center(
            child: LearningArt(artwork: LearningArtwork.medal, size: 156),
          ),
          const SizedBox(height: 8),
          const Center(child: LearningPill('BİR ADIM DAHA İLERİ')),
          const SizedBox(height: 20),
          Text(
            session.successPercentage >= 80
                ? 'Güzel iş!'
                : 'Her deneme bir adım.',
            style: theme.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Öğrendiklerini birlikte pekiştirelim.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            '%${session.successPercentage}',
            style: theme.textTheme.displayMedium?.copyWith(
              fontSize: MediaQuery.sizeOf(context).width < 360 ? 48 : 64,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            'başarı oranı',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (session.successPercentage / 100).clamp(0, 1),
            semanticsLabel: 'Başarı oranı',
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
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.task_alt_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(quiz.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Quiz tamamlandı', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LearningPanel(
            color: scheme.secondaryContainer,
            padding: const EdgeInsets.all(18),
            child: Text(
              session.incorrectCount == 0
                  ? 'Tüm soruları doğru yanıtladın. Bu emeğinle gurur duy.'
                  : '${session.incorrectCount} soruda gelişme alanın var. Derse dönüp konuyu yeniden keşfedebilirsin.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          LearningAction(label: 'Derse Dön', onPressed: () => context.pop()),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.pushNamed(AppRoutes.quizHistory),
            child: const Text('Quiz geçmişim'),
          ),
        ],
      ),
    );
  }
}
