import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/content_management/data/content_management_repository.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';

final contentModulesProvider = FutureProvider<List<ContentModuleSummary>>(
  (ref) => ref.watch(contentManagementRepositoryProvider).getModules(),
);

final contentModuleProvider = FutureProvider.family<ContentModule, String>(
  (ref, id) => ref.watch(contentManagementRepositoryProvider).getModule(id),
);

final contentLessonProvider = FutureProvider.family<ContentLesson, String>(
  (ref, id) => ref.watch(contentManagementRepositoryProvider).getLesson(id),
);

final contentMutationControllerProvider =
    AsyncNotifierProvider<ContentMutationController, void>(
      ContentMutationController.new,
    );

final class ContentMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> createModule(ModuleWriteInput input) => _mutate(() async {
    final id = await ref
        .read(contentManagementRepositoryProvider)
        .createModule(input);
    ref.invalidate(contentModulesProvider);
    return id;
  });

  Future<bool> updateModule(String id, ModuleWriteInput input) async {
    final result = await _mutate(() async {
      await ref
          .read(contentManagementRepositoryProvider)
          .updateModule(id, input);
      ref
        ..invalidate(contentModulesProvider)
        ..invalidate(contentModuleProvider(id));
      return true;
    });
    return result ?? false;
  }

  Future<String?> createLesson(String moduleId, LessonWriteInput input) =>
      _mutate(() async {
        final id = await ref
            .read(contentManagementRepositoryProvider)
            .createLesson(moduleId, input);
        ref
          ..invalidate(contentModulesProvider)
          ..invalidate(contentModuleProvider(moduleId));
        return id;
      });

  Future<bool> updateLesson(
    String moduleId,
    String id,
    LessonWriteInput input,
  ) async {
    final result = await _mutate(() async {
      await ref
          .read(contentManagementRepositoryProvider)
          .updateLesson(id, input);
      ref
        ..invalidate(contentModulesProvider)
        ..invalidate(contentModuleProvider(moduleId))
        ..invalidate(contentLessonProvider(id));
      return true;
    });
    return result ?? false;
  }

  Future<T?> _mutate<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      final result = await action();
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }
}
