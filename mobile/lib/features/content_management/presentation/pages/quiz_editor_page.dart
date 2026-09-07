import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';
import 'package:asli_app/features/content_management/presentation/providers/content_management_providers.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class QuizEditorPage extends ConsumerWidget {
  const QuizEditorPage({
    required this.moduleId,
    required this.lessonId,
    super.key,
  });

  final String moduleId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(contentQuizProvider(lessonId))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Quiz Yönetimi')),
            body: const ContentLoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('Quiz Yönetimi')),
            body: ContentErrorView(
              message: networkErrorMessage(error),
              onRetry: () => ref.invalidate(contentQuizProvider(lessonId)),
            ),
          ),
          data: (quiz) =>
              _QuizEditor(moduleId: moduleId, lessonId: lessonId, quiz: quiz),
        );
  }
}

class _QuizEditor extends ConsumerStatefulWidget {
  const _QuizEditor({
    required this.moduleId,
    required this.lessonId,
    required this.quiz,
  });

  final String moduleId;
  final String lessonId;
  final ContentQuiz? quiz;

  @override
  ConsumerState<_QuizEditor> createState() => _QuizEditorState();
}

class _QuizEditorState extends ConsumerState<_QuizEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late bool _isPublished;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.quiz?.title);
    _isPublished = widget.quiz?.isPublished ?? false;
  }

  @override
  void didUpdateWidget(covariant _QuizEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.quiz, widget.quiz)) {
      _titleController.text = widget.quiz?.title ?? _titleController.text;
      _isPublished = widget.quiz?.isPublished ?? false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isPublished && !_isPublishable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Yayınlamak için en az bir soru, her soruda 4 seçenek ve tek doğru cevap olmalıdır.',
          ),
        ),
      );
      return;
    }
    final succeeded = await ref
        .read(contentMutationControllerProvider.notifier)
        .saveQuiz(
          widget.lessonId,
          widget.quiz,
          QuizWriteInput(
            title: _titleController.text.trim(),
            isPublished: _isPublished,
          ),
        );
    if (!mounted) return;
    final mutation = ref.read(contentMutationControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? widget.quiz == null
                    ? 'Quiz oluşturuldu.'
                    : 'Quiz güncellendi.'
              : networkErrorMessage(mutation.error ?? Object()),
        ),
      ),
    );
  }

  bool get _isPublishable {
    final quiz = widget.quiz;
    return quiz != null &&
        quiz.questions.isNotEmpty &&
        quiz.questions.every(
          (question) =>
              question.options.length == 4 &&
              question.options.where((option) => option.isCorrect).length == 1,
        );
  }

  Future<void> _deleteQuiz() async {
    final quiz = widget.quiz;
    if (quiz == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quiz silinsin mi?'),
        content: const Text(
          'Quiz ve soruları içerik listesinden kaldırılacak. '
          'Önceki öğrenci denemeleri korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final succeeded = await ref
        .read(contentMutationControllerProvider.notifier)
        .deleteQuiz(widget.lessonId, quiz.id);
    if (!mounted) return;
    final error = ref.read(contentMutationControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded ? 'Quiz silindi.' : networkErrorMessage(error ?? Object()),
        ),
      ),
    );
    if (succeeded) context.pop(true);
  }

  Future<void> _deleteQuestion(ContentQuizQuestion question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Soru silinsin mi?'),
        content: const Text(
          'Soru ve seçenekleri quizden kaldırılacak. Quiz taslağa alınır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final succeeded = await ref
        .read(contentMutationControllerProvider.notifier)
        .deleteQuestion(widget.lessonId, question.id);
    if (!mounted) return;
    final error = ref.read(contentMutationControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded ? 'Soru silindi.' : networkErrorMessage(error ?? Object()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.quiz;
    final isLoading = ref.watch(contentMutationControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Yönetimi'),
        actions: [
          if (quiz != null)
            IconButton(
              key: const Key('delete_quiz_button'),
              tooltip: 'Quizi sil',
              onPressed: isLoading ? null : _deleteQuiz,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      floatingActionButton: quiz == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: FloatingActionButton.extended(
                key: const Key('create_question_button'),
                onPressed: () => context.pushNamed(
                  AppRoutes.contentQuestionCreate,
                  pathParameters: {
                    AppRoutes.contentModuleIdParameter: widget.moduleId,
                    AppRoutes.contentLessonIdParameter: widget.lessonId,
                    AppRoutes.contentQuizIdParameter: quiz.id,
                  },
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Soru Ekle'),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          96,
        ),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  key: const Key('quiz_title_field'),
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Quiz başlığı'),
                  maxLength: 200,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Quiz başlığı zorunludur.'
                      : null,
                ),
                SwitchListTile.adaptive(
                  key: const Key('quiz_published_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yayınla'),
                  subtitle: Text(
                    _isPublished ? 'Quiz yayında.' : 'Quiz taslak.',
                  ),
                  value: _isPublished,
                  onChanged: isLoading
                      ? null
                      : (value) => setState(() => _isPublished = value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('save_quiz_button'),
                    onPressed: isLoading ? null : _save,
                    icon: isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(quiz == null ? 'Quiz Oluştur' : 'Quizi Kaydet'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Sorular', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          if (quiz == null)
            const Text(
              'Soruları eklemek için önce quizi taslak olarak oluşturun.',
            )
          else if (quiz.questions.isEmpty)
            const Text('Henüz soru eklenmemiş.')
          else
            ...quiz.questions.map(
              (question) => Card(
                child: ListTile(
                  title: Text(question.prompt),
                  subtitle: Text(
                    'Sıra ${question.order} · ${question.options.length}/4 seçenek',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined),
                      IconButton(
                        key: Key('delete_question_${question.id}'),
                        tooltip: 'Soruyu sil',
                        onPressed: isLoading
                            ? null
                            : () => _deleteQuestion(question),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  onTap: () => context.pushNamed(
                    AppRoutes.contentQuestionEdit,
                    pathParameters: {
                      AppRoutes.contentModuleIdParameter: widget.moduleId,
                      AppRoutes.contentLessonIdParameter: widget.lessonId,
                      AppRoutes.contentQuizIdParameter: quiz.id,
                      AppRoutes.contentQuestionIdParameter: question.id,
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
