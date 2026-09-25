import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';

class LessonQuizCard extends ConsumerWidget {
  const LessonQuizCard({
    required this.moduleId,
    required this.lessonId,
    super.key,
  });
  final String moduleId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(lessonQuizStatusProvider(lessonId))
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(lessonQuizStatusProvider(lessonId)),
          child: const Text('Quiz durumu yüklenemedi. Yenile'),
        ),
        data: (quiz) => Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  quiz.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (quiz.status == 'Completed') ...[
                  const Text('Quiz Tamamlandı'),
                  Text(
                    '${quiz.result!.correctCount} doğru • ${quiz.result!.incorrectCount} yanlış • %${quiz.result!.successPercentage}',
                  ),
                ] else ...[
                  if (quiz.status == 'InProgress') ...[
                    Text(
                      '${quiz.savedAnswers.length} / ${quiz.questions.length} soru tamamlandı',
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: quiz.savedAnswers.length / quiz.questions.length,
                      semanticsLabel: 'Kaydedilen cevaplar',
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      await context.pushNamed(
                        AppRoutes.quiz,
                        pathParameters: {
                          AppRoutes.moduleIdParameter: moduleId,
                          AppRoutes.lessonIdParameter: lessonId,
                        },
                      );
                      if (context.mounted) {
                        ref.invalidate(lessonQuizStatusProvider(lessonId));
                      }
                    },
                    child: Text(
                      quiz.status == 'InProgress'
                          ? 'Quiz’e Devam Et'
                          : 'Quiz’e Başla',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}
