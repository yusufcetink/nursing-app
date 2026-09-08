import 'package:asli_app/features/content_management/data/content_management_repository.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';
import 'package:asli_app/features/content_management/presentation/providers/content_management_providers.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_content_management_repository.dart';
import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  test('içerik bloğu kaydedilince öğrenci ders cacheini yeniler', () async {
    final educationRepository = FakeEducationRepository();
    final container = ProviderContainer(
      overrides: [
        contentManagementRepositoryProvider.overrideWithValue(
          FakeContentManagementRepository(),
        ),
        educationRepositoryProvider.overrideWithValue(educationRepository),
      ],
    );
    addTearDown(container.dispose);

    const selection = (
      moduleId: 'nursing-fundamentals',
      lessonId: 'nursing-roles',
    );
    final subscription = container.listen(
      lessonProvider(selection),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(lessonProvider(selection).future);
    expect(educationRepository.getLessonCallCount, 1);

    await container
        .read(contentMutationControllerProvider.notifier)
        .createContentBlock(
          selection.lessonId,
          const ContentBlockWriteInput(
            blockType: ContentBlockType.text,
            textContent: 'Yeni içerik',
            sortOrder: 0,
          ),
        );
    await container.read(lessonProvider(selection).future);

    expect(educationRepository.getLessonCallCount, 2);
  });
}
