import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';
import 'package:asli_app/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';

import '../../../../helpers/fake_auth_repository.dart';
import '../../../../helpers/fake_learning_repositories.dart';

void main() {
  test('profil özetini auth ve progress state üzerinden üretir', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(restoredUser: FakeAuthRepository.user),
        ),
        progressRepositoryProvider.overrideWithValue(
          FakeProgressRepository(completedLessons: [testCompletedLesson]),
        ),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(results: [testProfileQuizResult]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    final overview = await container.read(profileOverviewProvider.future);
    expect(overview.user.fullName, 'Ayşe Yılmaz');
    expect(overview.user.role, UserRole.student);
    expect(overview.completedLessonCount, 1);
    expect(overview.completedQuizCount, 1);
    expect(
      overview.quizResults.single.quizTitle,
      'Hemşirenin Temel Rolleri Quizi',
    );
    expect(overview.quizResults.single.lessonTitle, 'Hemşirenin Temel Rolleri');
    expect(overview.quizResults.single.totalQuestionCount, 2);
  });
}
