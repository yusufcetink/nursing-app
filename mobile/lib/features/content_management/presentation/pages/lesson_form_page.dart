import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
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
  late final TextEditingController _durationController;
  late final TextEditingController _orderController;
  late bool _isPublished;
  late List<ContentLessonContentBlock> _blocks;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    final lesson = widget.lesson;
    _titleController = TextEditingController(text: lesson?.title);
    _descriptionController = TextEditingController(text: lesson?.description);
    _blocks = List.of(lesson?.blocks ?? const []);
    _durationController = TextEditingController(
      text: lesson?.estimatedDurationMinutes.toString() ?? '1',
    );
    _orderController = TextEditingController(
      text: lesson?.order.toString() ?? '0',
    );
    _isPublished = lesson?.isPublished ?? false;
  }

  @override
  void didUpdateWidget(covariant _LessonForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lesson != oldWidget.lesson) {
      _blocks = List.of(widget.lesson?.blocks ?? const []);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final input = LessonWriteInput(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      estimatedDurationMinutes: int.parse(_durationController.text),
      order: int.parse(_orderController.text),
      isPublished: _isPublished,
    );
    final controller = ref.read(contentMutationControllerProvider.notifier);
    final lesson = widget.lesson;
    final createdLessonId = lesson == null
        ? await controller.createLesson(widget.moduleId, input)
        : null;
    final succeeded = lesson == null
        ? createdLessonId != null
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
    if (createdLessonId != null) {
      context.pushReplacementNamed(
        AppRoutes.contentLessonEdit,
        pathParameters: {
          AppRoutes.contentModuleIdParameter: widget.moduleId,
          AppRoutes.contentLessonIdParameter: createdLessonId,
        },
      );
    } else {
      context.pop(true);
    }
  }

  Future<void> _addBlock() async {
    final type = await showModalBottomSheet<ContentBlockType>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('İçerik Ekle')),
            for (final item in const [
              (ContentBlockType.heading, 'Başlık', Icons.title),
              (ContentBlockType.text, 'Metin', Icons.notes),
              (ContentBlockType.image, 'Görsel', Icons.image_outlined),
              (ContentBlockType.video, 'Video', Icons.video_file_outlined),
            ])
              ListTile(
                leading: Icon(item.$3),
                title: Text(item.$2),
                onTap: () => Navigator.pop(context, item.$1),
              ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    if (type == ContentBlockType.heading || type == ContentBlockType.text) {
      await _editTextBlock(type: type);
    } else {
      await _addMediaBlock(type);
    }
  }

  Future<void> _editTextBlock({
    required ContentBlockType type,
    ContentLessonContentBlock? block,
  }) async {
    var textValue = block?.textContent ?? '';
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == ContentBlockType.heading ? 'Başlık' : 'Metin'),
        content: TextFormField(
          initialValue: block?.textContent,
          onChanged: (value) => textValue = value,
          autofocus: true,
          minLines: type == ContentBlockType.text ? 4 : 1,
          maxLines: type == ContentBlockType.text ? 10 : 2,
          decoration: const InputDecoration(labelText: 'İçerik'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textValue.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty || !mounted) return;
    final input = ContentBlockWriteInput(
      blockType: type,
      textContent: text,
      sortOrder: block?.sortOrder ?? _blocks.length,
    );
    final controller = ref.read(contentMutationControllerProvider.notifier);
    if (block == null) {
      await controller.createContentBlock(widget.lesson!.id, input);
    } else {
      await controller.updateContentBlock(widget.lesson!.id, block.id, input);
    }
  }

  Future<void> _addMediaBlock(ContentBlockType type) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: type == ContentBlockType.image
          ? const ['jpg', 'jpeg', 'png', 'webp']
          : const ['mp4'],
    );
    if (file?.path == null || !mounted) return;
    setState(() => _uploadProgress = 0);
    final controller = ref.read(contentMutationControllerProvider.notifier);
    final media = await controller.uploadLessonMedia(
      lessonId: widget.lesson!.id,
      filePath: file!.path!,
      fileName: file.name,
      sortOrder: _blocks.length,
      onSendProgress: (sent, total) {
        if (mounted && total > 0) {
          setState(() => _uploadProgress = sent / total);
        }
      },
    );
    if (!mounted) return;
    setState(() => _uploadProgress = null);
    if (media == null) return;
    final blockId = await controller.createContentBlock(
      widget.lesson!.id,
      ContentBlockWriteInput(
        blockType: type,
        mediaId: media.id,
        sortOrder: _blocks.length,
      ),
    );
    if (blockId == null) {
      await controller.deleteLessonMedia(widget.lesson!.id, media.id);
    }
  }

  Future<void> _deleteBlock(ContentLessonContentBlock block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İçerik bloğu silinsin mi?'),
        content: const Text('Bu içerik bloğu kalıcı olarak silinecek.'),
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
        .deleteContentBlock(block.lessonId, block.id);
    if (!mounted) return;
    final error = ref.read(contentMutationControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? 'İçerik silindi.'
              : networkErrorMessage(error ?? Object()),
        ),
      ),
    );
  }

  Future<void> _reorderBlocks(int oldIndex, int newIndex) async {
    setState(() {
      final block = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, block);
    });
    final succeeded = await ref
        .read(contentMutationControllerProvider.notifier)
        .reorderContentBlocks(widget.lesson!.id, [
          for (final (index, block) in _blocks.indexed)
            (blockId: block.id, sortOrder: index),
        ]);
    if (!succeeded && mounted) {
      ref.invalidate(contentLessonProvider(widget.lesson!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(contentMutationControllerProvider).isLoading;
    final isEditing = widget.lesson != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Dersi Düzenle' : 'Yeni Ders')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
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
                if (!isEditing) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'İçerik blokları, ders oluşturulduktan sonra eklenebilir.',
                  ),
                ],
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
                if (widget.lesson != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ders İçeriği',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        key: const Key('add_content_block_button'),
                        onPressed: isLoading ? null : _addBlock,
                        icon: const Icon(Icons.add),
                        label: const Text('İçerik Ekle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_blocks.isEmpty)
                    const Text('Bu derse henüz içerik bloğu eklenmemiş.')
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: _blocks.length,
                      onReorderItem: isLoading ? (_, _) {} : _reorderBlocks,
                      itemBuilder: (context, index) {
                        final block = _blocks[index];
                        final isText =
                            block.blockType == ContentBlockType.heading ||
                            block.blockType == ContentBlockType.text;
                        return Card(
                          key: ValueKey(block.id),
                          child: ListTile(
                            leading: Icon(_blockIcon(block.blockType)),
                            title: Text(
                              block.textContent ??
                                  block.media?.originalFileName ??
                                  'Medya',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(_blockLabel(block.blockType)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isText)
                                  IconButton(
                                    tooltip: 'Düzenle',
                                    onPressed: isLoading
                                        ? null
                                        : () => _editTextBlock(
                                            type: block.blockType,
                                            block: block,
                                          ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                IconButton(
                                  tooltip: 'Sil',
                                  onPressed: isLoading
                                      ? null
                                      : () => _deleteBlock(block),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(Icons.drag_handle),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (_uploadProgress != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Yükleniyor: ${(_uploadProgress! * 100).round()}%',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('manage_quiz_button'),
                    onPressed: isLoading
                        ? null
                        : () => context.pushNamed(
                            AppRoutes.contentQuiz,
                            pathParameters: {
                              AppRoutes.contentModuleIdParameter:
                                  widget.moduleId,
                              AppRoutes.contentLessonIdParameter:
                                  widget.lesson!.id,
                            },
                          ),
                    icon: const Icon(Icons.quiz_outlined),
                    label: Text(
                      widget.lesson!.quizId == null
                          ? 'Quiz Oluştur'
                          : 'Quizi Yönet',
                    ),
                  ),
                ],
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

  static IconData _blockIcon(ContentBlockType type) => switch (type) {
    ContentBlockType.heading => Icons.title,
    ContentBlockType.text => Icons.notes,
    ContentBlockType.image => Icons.image_outlined,
    ContentBlockType.video => Icons.video_file_outlined,
  };

  static String _blockLabel(ContentBlockType type) => switch (type) {
    ContentBlockType.heading => 'Başlık',
    ContentBlockType.text => 'Metin',
    ContentBlockType.image => 'Görsel',
    ContentBlockType.video => 'Video',
  };
}
