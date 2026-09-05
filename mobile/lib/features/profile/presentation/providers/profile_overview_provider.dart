import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/profile/domain/models/profile_overview.dart';
import 'package:asli_app/features/profile/domain/models/profile_user.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';

final profileUserProvider = Provider<ProfileUser>((ref) {
  final authenticatedUser = ref.watch(authControllerProvider).requireValue;
  if (authenticatedUser == null) {
    throw StateError('Profile requires an authenticated user.');
  }
  return ProfileUser(
    firstName: authenticatedUser.firstName,
    lastName: authenticatedUser.lastName,
    email: authenticatedUser.email,
    role: authenticatedUser.primaryRole,
  );
});

final quizHistoryProvider = FutureProvider<List<ProfileQuizResult>>(
  (ref) => ref.watch(profileRepositoryProvider).getQuizHistory(),
);

final profileOverviewProvider = FutureProvider<ProfileOverview>((ref) async {
  final user = ref.watch(profileUserProvider);
  final progress = await ref.watch(progressControllerProvider.future);
  final quizResults = await ref.watch(quizHistoryProvider.future);
  return ProfileOverview(
    user: user,
    completedLessonCount: progress.completedLessonIds.length,
    quizResults: quizResults,
  );
});

final profileQuizResultProvider =
    FutureProvider.family<ProfileQuizResult, String>((ref, attemptId) {
      return ref
          .watch(profileRepositoryProvider)
          .getQuizHistoryDetail(attemptId);
    });
