import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';
import 'package:asli_app/features/content_management/presentation/providers/content_management_providers.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class ContentModulesPage extends ConsumerWidget {
  const ContentModulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(contentModulesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('İçerik Yönetimi')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create_module_button'),
        onPressed: () => context.pushNamed(AppRoutes.contentModuleCreate),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Modül Ekle'),
      ),
      body: modules.when(
        loading: () => const ContentLoadingView(),
        error: (error, _) => ContentErrorView(
          message: networkErrorMessage(error),
          onRetry: () => ref.invalidate(contentModulesProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyContentView(
                message: 'Henüz eğitim modülü oluşturulmamış.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(contentModulesProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    96,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _ContentModuleCard(module: items[index]),
                ),
              ),
      ),
    );
  }
}

class _ContentModuleCard extends ConsumerWidget {
  const _ContentModuleCard({required this.module});

  final ContentModuleSummary module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.pushNamed(
          AppRoutes.contentModule,
          pathParameters: {AppRoutes.contentModuleIdParameter: module.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      module.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Modülü düzenle',
                    onPressed: () => context.pushNamed(
                      AppRoutes.contentModuleEdit,
                      pathParameters: {
                        AppRoutes.contentModuleIdParameter: module.id,
                      },
                    ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    key: Key('delete_module_${module.id}'),
                    tooltip: 'Modülü sil',
                    onPressed: () => _delete(context, ref),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              Text(
                module.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Chip(
                    avatar: Icon(
                      module.isPublished
                          ? Icons.public_rounded
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    label: Text(module.isPublished ? 'Yayında' : 'Taslak'),
                  ),
                  Chip(label: Text('${module.lessonCount} ders')),
                  Chip(label: Text('Sıra ${module.order}')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modül silinsin mi?'),
        content: const Text(
          'Modül, bağlı dersler ve quizler içerik listelerinden kaldırılacak. '
          'Öğrenci ilerlemesi ve quiz geçmişi korunur.',
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
    if (confirmed != true || !context.mounted) return;

    final succeeded = await ref
        .read(contentMutationControllerProvider.notifier)
        .deleteModule(module.id);
    if (!context.mounted) return;
    final error = ref.read(contentMutationControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded ? 'Modül silindi.' : networkErrorMessage(error ?? Object()),
        ),
      ),
    );
  }
}
