import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';
import 'package:asli_app/features/content_management/presentation/providers/content_management_providers.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class LessonFormPage extends ConsumerWidget {
  const LessonFormPage({required this.moduleId, this.lessonId, super.key});

  final String moduleId;
  final String? lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = lessonId;
    if (id == null) return _LessonForm(moduleId: moduleId);
    return ref
        .watch(contentLessonProvider(id))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Dersi Düzenle')),
            body: const ContentLoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('Dersi Düzenle')),
            body: ContentErrorView(
              message: networkErrorMessage(error),
              onRetry: () => ref.invalidate(contentLessonProvider(id)),
            ),
          ),
          data: (lesson) => _LessonForm(moduleId: moduleId, lesson: lesson),
        );
  }
}

class _LessonForm extends ConsumerStatefulWidget {
  const _LessonForm({required this.moduleId, this.lesson});

  final String moduleId;
  final ContentLesson? lesson;

  @override
  ConsumerState<_LessonForm> createState() => _LessonFormState();
}

class _LessonFormState extends ConsumerState<_LessonForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _contentController;
  late final TextEditingController _durationController;
  late final TextEditingController _orderController;
  late bool _isPublished;

  @override
  void initState() {
    super.initState();
    final lesson = widget.lesson;
    _titleController = TextEditingController(text: lesson?.title);
    _descriptionController = TextEditingController(text: lesson?.description);
    _contentController = TextEditingController(text: lesson?.content);
    _durationController = TextEditingController(
      text: lesson?.estimatedDurationMinutes.toString() ?? '1',
    );
    _orderController = TextEditingController(
      text: lesson?.order.toString() ?? '0',
    );
    _isPublished = lesson?.isPublished ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _durationController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final input = LessonWriteInput(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      content: _contentController.text.trim(),
      estimatedDurationMinutes: int.parse(_durationController.text),
      order: int.parse(_orderController.text),
      isPublished: _isPublished,
    );
    final controller = ref.read(contentMutationControllerProvider.notifier);
    final lesson = widget.lesson;
    final succeeded = lesson == null
        ? await controller.createLesson(widget.moduleId, input) != null
        : await controller.updateLesson(widget.moduleId, lesson.id, input);
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
          lesson == null ? 'Ders oluşturuldu.' : 'Ders güncellendi.',
        ),
      ),
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(contentMutationControllerProvider).isLoading;
    final isEditing = widget.lesson != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Dersi Düzenle' : 'Yeni Ders')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('lesson_title_field'),
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                  maxLength: 200,
                  validator: _required,
                ),
                TextFormField(
                  key: const Key('lesson_description_field'),
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  validator: _required,
                ),
                TextFormField(
                  key: const Key('lesson_content_field'),
                  controller: _contentController,
                  decoration: const InputDecoration(labelText: 'Ders içeriği'),
                  minLines: 8,
                  maxLines: 16,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('lesson_duration_field'),
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Süre (dk)',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _positiveNumber,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        key: const Key('lesson_order_field'),
                        controller: _orderController,
                        decoration: const InputDecoration(labelText: 'Sıra'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _nonNegativeNumber,
                      ),
                    ),
                  ],
                ),
                SwitchListTile.adaptive(
                  key: const Key('lesson_published_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yayınla'),
                  subtitle: Text(
                    _isPublished
                        ? 'Ders öğrencilere görünür.'
                        : 'Ders taslak olarak saklanır.',
                  ),
                  value: _isPublished,
                  onChanged: isLoading
                      ? null
                      : (value) => setState(() => _isPublished = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  key: const Key('save_lesson_button'),
                  onPressed: isLoading ? null : _submit,
                  icon: isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    isEditing ? 'Değişiklikleri Kaydet' : 'Dersi Oluştur',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bu alan zorunludur.' : null;

  static String? _positiveNumber(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 1 ? 'En az 1 girin.' : null;
  }

  static String? _nonNegativeNumber(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 0 ? 'Geçerli bir sıra girin.' : null;
  }
}
