import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';
import 'package:asli_app/features/content_management/presentation/providers/content_management_providers.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class ModuleFormPage extends ConsumerWidget {
  const ModuleFormPage({this.moduleId, super.key});

  final String? moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = moduleId;
    if (id == null) {
      return const _ModuleForm();
    }

    return ref
        .watch(contentModuleProvider(id))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Modülü Düzenle')),
            body: const ContentLoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('Modülü Düzenle')),
            body: ContentErrorView(
              message: networkErrorMessage(error),
              onRetry: () => ref.invalidate(contentModuleProvider(id)),
            ),
          ),
          data: (module) => _ModuleForm(module: module),
        );
  }
}

class _ModuleForm extends ConsumerStatefulWidget {
  const _ModuleForm({this.module});

  final ContentModule? module;

  @override
  ConsumerState<_ModuleForm> createState() => _ModuleFormState();
}

class _ModuleFormState extends ConsumerState<_ModuleForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;
  late bool _isPublished;

  @override
  void initState() {
    super.initState();
    final module = widget.module;
    _titleController = TextEditingController(text: module?.title);
    _descriptionController = TextEditingController(text: module?.description);
    _orderController = TextEditingController(
      text: module?.order.toString() ?? '0',
    );
    _isPublished = module?.isPublished ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final input = ModuleWriteInput(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      order: int.parse(_orderController.text),
      isPublished: _isPublished,
    );
    final controller = ref.read(contentMutationControllerProvider.notifier);
    final module = widget.module;
    final succeeded = module == null
        ? await controller.createModule(input) != null
        : await controller.updateModule(module.id, input);
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
          module == null ? 'Modül oluşturuldu.' : 'Modül güncellendi.',
        ),
      ),
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(contentMutationControllerProvider).isLoading;
    final isEditing = widget.module != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Modülü Düzenle' : 'Yeni Modül')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('module_title_field'),
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                  maxLength: 200,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  key: const Key('module_description_field'),
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 6,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  key: const Key('module_order_field'),
                  controller: _orderController,
                  decoration: const InputDecoration(labelText: 'Sıra'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _nonNegativeNumber,
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile.adaptive(
                  key: const Key('module_published_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yayınla'),
                  subtitle: Text(
                    _isPublished
                        ? 'Modül öğrencilere görünür.'
                        : 'Modül taslak olarak saklanır.',
                  ),
                  value: _isPublished,
                  onChanged: isLoading
                      ? null
                      : (value) => setState(() => _isPublished = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  key: const Key('save_module_button'),
                  onPressed: isLoading ? null : _submit,
                  icon: isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    isEditing ? 'Değişiklikleri Kaydet' : 'Modülü Oluştur',
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

  static String? _nonNegativeNumber(String? value) {
    final number = int.tryParse(value ?? '');
    return number == null || number < 0 ? 'Geçerli bir sıra girin.' : null;
  }
}
