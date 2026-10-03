import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/quiz/presentation/controllers/quiz_controller.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';

class LessonQuizCard extends ConsumerWidget {
  const LessonQuizCard({
    required this.moduleId,
    required this.lessonId,
    required this.quizId,
    super.key,
  });
  final String moduleId;
  final String lessonId;
  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonCompleted = ref.watch(lessonCompletedProvider(lessonId));
    return ref
        .watch(quizStatusProvider(quizId))
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(quizStatusProvider(quizId)),
            child: const Text('Quiz durumu yüklenemedi. Yenile'),
          ),
          data: (quiz) => Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      quiz.status == 'Completed'
                          ? Icons.task_alt_rounded
                          : quiz.status == 'InProgress'
                          ? Icons.play_circle_outline_rounded
                          : !lessonCompleted
                          ? Icons.lock_outline
                          : Icons.quiz_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    quiz.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (quiz.status == 'Completed') ...[
                    const Text('Quiz Tamamlandı'),
                    const SizedBox(height: 6),
                    Text(
                      '${quiz.result!.correctCount} doğru • ${quiz.result!.incorrectCount} yanlış • %${quiz.result!.successPercentage}',
                    ),
                  ] else ...[
                    if (!lessonCompleted && quiz.status != 'InProgress') ...[
                      const Text('Quizi açmak için önce dersi tamamla.'),
                    ],
                    if (quiz.status == 'InProgress') ...[
                      const Text('Devam ediyor'),
                      const SizedBox(height: 6),
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
                      onPressed: !lessonCompleted && quiz.status != 'InProgress'
                          ? null
                          : () async {
                              await context.pushNamed(
                                AppRoutes.quiz,
                                pathParameters: {
                                  AppRoutes.moduleIdParameter: moduleId,
                                  AppRoutes.lessonIdParameter: lessonId,
                                  AppRoutes.quizIdParameter: quizId,
                                },
                              );
                              if (context.mounted) {
                                ref.invalidate(quizStatusProvider(quizId));
                              }
                            },
                      child: Text(
                        quiz.status == 'InProgress'
                            ? 'Quiz’e Devam Et'
                            : !lessonCompleted
                            ? 'Quiz Kilitli'
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
}
