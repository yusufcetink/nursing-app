import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/content_management/presentation/providers/content_management_providers.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class LessonQuizzesPage extends ConsumerWidget {
  const LessonQuizzesPage({
    required this.moduleId,
    required this.lessonId,
    super.key,
  });
  final String moduleId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openQuiz(String id) => context.pushNamed(
      AppRoutes.contentQuiz,
      pathParameters: {
        AppRoutes.contentModuleIdParameter: moduleId,
        AppRoutes.contentLessonIdParameter: lessonId,
        AppRoutes.contentQuizIdParameter: id,
      },
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Dersin Quizleri')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openQuiz('new'),
        icon: const Icon(Icons.add),
        label: const Text('Quiz Oluştur'),
      ),
      body: ref
          .watch(contentLessonProvider(lessonId))
          .when(
            loading: () => const ContentLoadingView(),
            error: (error, _) => ContentErrorView(
              message: networkErrorMessage(error),
              onRetry: () => ref.invalidate(contentLessonProvider(lessonId)),
            ),
            data: (lesson) => lesson.quizzes.isEmpty
                ? const EmptyContentView(message: 'Bu derste henüz quiz yok.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      for (final quiz in lesson.quizzes)
                        Card(
                          child: ListTile(
                            key: ValueKey(quiz.id),
                            title: Text(quiz.title),
                            subtitle: Text(
                              'Sıra: ${quiz.order} • ${quiz.isPublished ? "Yayında" : "Taslak"}',
                            ),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () => openQuiz(quiz.id),
                          ),
                        ),
                    ],
                  ),
          ),
    );
  }
}
