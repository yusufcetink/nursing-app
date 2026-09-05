import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';
import 'package:asli_app/features/content_management/presentation/providers/content_management_providers.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class ContentModuleDetailPage extends ConsumerWidget {
  const ContentModuleDetailPage({required this.moduleId, super.key});

  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final module = ref.watch(contentModuleProvider(moduleId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modül İçeriği'),
        actions: [
          IconButton(
            tooltip: 'Modülü düzenle',
            onPressed: () => context.pushNamed(
              AppRoutes.contentModuleEdit,
              pathParameters: {AppRoutes.contentModuleIdParameter: moduleId},
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create_lesson_button'),
        onPressed: () => context.pushNamed(
          AppRoutes.contentLessonCreate,
          pathParameters: {AppRoutes.contentModuleIdParameter: moduleId},
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ders Ekle'),
      ),
      body: module.when(
        loading: () => const ContentLoadingView(),
        error: (error, _) => ContentErrorView(
          message: networkErrorMessage(error),
          onRetry: () => ref.invalidate(contentModuleProvider(moduleId)),
        ),
        data: (item) => RefreshIndicator(
          onRefresh: () => ref.refresh(contentModuleProvider(moduleId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              96,
            ),
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(item.description),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(item.isPublished ? 'Yayında' : 'Taslak'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Dersler', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              if (item.lessons.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    'Bu modülde henüz ders yok.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...item.lessons.map(
                  (lesson) => _LessonCard(moduleId: moduleId, lesson: lesson),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.moduleId, required this.lesson});

  final String moduleId;
  final ContentLessonSummary lesson;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(lesson.title),
        subtitle: Text(
          '${lesson.isPublished ? 'Yayında' : 'Taslak'} · '
          '${lesson.estimatedDurationMinutes} dk · Sıra ${lesson.order}',
        ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => context.pushNamed(
          AppRoutes.contentLessonEdit,
          pathParameters: {
            AppRoutes.contentModuleIdParameter: moduleId,
            AppRoutes.contentLessonIdParameter: lesson.id,
          },
        ),
      ),
    );
  }
}
