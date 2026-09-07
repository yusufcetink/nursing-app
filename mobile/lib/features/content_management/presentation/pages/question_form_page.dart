import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';
import 'package:asli_app/features/content_management/presentation/providers/content_management_providers.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class QuestionFormPage extends ConsumerWidget {
  const QuestionFormPage({
    required this.lessonId,
    required this.quizId,
    this.questionId,
    super.key,
  });

  final String lessonId;
  final String quizId;
  final String? questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(contentQuizProvider(lessonId))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Soru')),
            body: const ContentLoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('Soru')),
            body: ContentErrorView(
              message: networkErrorMessage(error),
              onRetry: () => ref.invalidate(contentQuizProvider(lessonId)),
            ),
          ),
          data: (quiz) {
            if (quiz == null) {
              return const Scaffold(
                body: EmptyContentView(message: 'Quiz bulunamadı.'),
              );
            }
            ContentQuizQuestion? question;
            if (questionId != null) {
              question = quiz.questions
                  .where((item) => item.id == questionId)
                  .firstOrNull;
              if (question == null) {
                return const Scaffold(
                  body: EmptyContentView(message: 'Soru bulunamadı.'),
                );
              }
            }
            return _QuestionForm(
              lessonId: lessonId,
              quizId: quizId,
              question: question,
              initialOrder:
                  question?.order ??
                  quiz.questions.fold(
                    0,
                    (next, item) => item.order >= next ? item.order + 1 : next,
                  ),
              unavailableOrders: question == null
                  ? quiz.questions.map((item) => item.order).toSet()
                  : const <int>{},
            );
          },
        );
  }
}

class _QuestionForm extends ConsumerStatefulWidget {
  const _QuestionForm({
    required this.lessonId,
    required this.quizId,
    required this.question,
    required this.initialOrder,
    required this.unavailableOrders,
  });

  final String lessonId;
  final String quizId;
  final ContentQuizQuestion? question;
  final int initialOrder;
  final Set<int> unavailableOrders;

  @override
  ConsumerState<_QuestionForm> createState() => _QuestionFormState();
}

class _QuestionFormState extends ConsumerState<_QuestionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _promptController;
  late final TextEditingController _orderController;
  late final List<TextEditingController> _optionControllers;
  late final List<TextEditingController> _optionOrderControllers;
  late int _correctOptionIndex;

  @override
  void initState() {
    super.initState();
    final question = widget.question;
    _promptController = TextEditingController(text: question?.prompt);
    _orderController = TextEditingController(
      text: widget.initialOrder.toString(),
    );
    _optionControllers = List.generate(
      4,
      (index) => TextEditingController(
        text: index < (question?.options.length ?? 0)
            ? question!.options[index].text
            : '',
      ),
    );
    _optionOrderControllers = List.generate(
      4,
      (index) => TextEditingController(
        text: index < (question?.options.length ?? 0)
            ? question!.options[index].order.toString()
            : (index + 1).toString(),
      ),
    );
    final correctIndex =
        question?.options.indexWhere((option) => option.isCorrect) ?? -1;
    _correctOptionIndex = correctIndex < 0 ? 0 : correctIndex;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _orderController.dispose();
    for (final controller in [
      ..._optionControllers,
      ..._optionOrderControllers,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final optionOrders = _optionOrderControllers
        .map((controller) => int.parse(controller.text))
        .toList();
    if (optionOrders.toSet().length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seçenek sıraları birbirinden farklı olmalıdır.'),
        ),
      );
      return;
    }
    final options = List.generate(
      4,
      (index) => QuizOptionWriteInput(
        text: _optionControllers[index].text.trim(),
        isCorrect: index == _correctOptionIndex,
        order: optionOrders[index],
      ),
    );
    final succeeded = await ref
        .read(contentMutationControllerProvider.notifier)
        .saveQuestion(
          lessonId: widget.lessonId,
          quizId: widget.quizId,
          question: widget.question,
          input: QuizQuestionWriteInput(
            prompt: _promptController.text.trim(),
            order: int.parse(_orderController.text),
          ),
          options: options,
        );
    if (!mounted) return;
    if (!succeeded) {
      final error = ref.read(contentMutationControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(networkErrorMessage(error ?? Object()))),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.question == null
              ? 'Soru eklendi. Quiz taslak olarak güncellendi.'
              : 'Soru güncellendi. Quiz taslak olarak güncellendi.',
        ),
      ),
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(contentMutationControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.question == null ? 'Yeni Soru' : 'Soruyu Düzenle'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              96,
            ),
            children: [
              TextFormField(
                key: const Key('question_prompt_field'),
                controller: _promptController,
                decoration: const InputDecoration(labelText: 'Soru'),
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                validator: _required,
              ),
              TextFormField(
                key: const Key('question_order_field'),
                controller: _orderController,
                decoration: const InputDecoration(labelText: 'Soru sırası'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _questionOrderValidator,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Seçenekler · doğru cevabı seçin',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (var index = 0; index < 4; index++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        Tooltip(
                          message: 'Doğru cevap olarak seç',
                          child: Checkbox(
                            key: Key('correct_option_$index'),
                            value: index == _correctOptionIndex,
                            onChanged: isLoading
                                ? null
                                : (_) => setState(
                                    () => _correctOptionIndex = index,
                                  ),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            key: Key('option_${index}_text_field'),
                            controller: _optionControllers[index],
                            decoration: InputDecoration(
                              labelText: '${index + 1}. seçenek',
                            ),
                            maxLength: 500,
                            validator: _required,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        SizedBox(
                          width: 72,
                          child: TextFormField(
                            key: Key('option_${index}_order_field'),
                            controller: _optionOrderControllers[index],
                            decoration: const InputDecoration(
                              labelText: 'Sıra',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: _nonNegative,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const Key('save_question_button'),
                onPressed: isLoading ? null : _save,
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Soruyu Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bu alan zorunludur.' : null;

  static String? _nonNegative(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 0 ? 'Geçerli bir sıra girin.' : null;
  }

  String? _questionOrderValidator(String? value) {
    final validation = _nonNegative(value);
    if (validation != null) return validation;
    return widget.unavailableOrders.contains(int.parse(value!))
        ? 'Bu sıra başka bir soruda kullanılıyor.'
        : null;
  }
}
