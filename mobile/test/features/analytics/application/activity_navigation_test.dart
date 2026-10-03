import 'package:asli_app/features/leaderboard/data/leaderboard_repository.dart';
import 'package:asli_app/features/leaderboard/presentation/leaderboard_providers.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/features/analytics/application/activity_tracker.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/education/data/education_repository.dart';
import 'package:asli_app/features/profile/data/profile_repository.dart';
import 'package:asli_app/features/progress/data/progress_repository.dart';
import 'package:asli_app/features/quiz/data/quiz_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_activity_repository.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_learning_repositories.dart';

void main() {
  testWidgets(
    'restored shell tabs and pop report the visible screen with IDs',
    (tester) async {
      var now = DateTime.utc(2026, 9, 13);
      final repository = FakeActivityRepository();
      final tracker = ActivityTracker(repository, now: () => now);
      final container = ProviderContainer(
        overrides: [
          activityTrackerProvider.overrideWithValue(tracker),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(restoredUser: FakeAuthRepository.user),
          ),
          educationRepositoryProvider.overrideWithValue(
            FakeEducationRepository(),
          ),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          leaderboardCoursesProvider.overrideWith((ref) async => const []),
          leaderboardProvider.overrideWith(
            (ref, selection) async => const LeaderboardData(
              entries: [],
              totalUsers: 0,
              offset: 0,
              limit: 20,
            ),
          ),
          quizRepositoryProvider.overrideWithValue(FakeQuizRepository()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      now = now.add(const Duration(seconds: 2));
      router.pushNamed(
        AppRoutes.educationModule,
        pathParameters: {'moduleId': 'nursing-fundamentals'},
      );
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 3));
      router.pushNamed(
        AppRoutes.lesson,
        pathParameters: {
          'moduleId': 'nursing-fundamentals',
          'lessonId': 'nursing-roles',
        },
      );
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 4));
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 5));
      await tester.tap(find.text('Eğitim'));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 6));
      router.pop();
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 7));
      await tracker.endSession();
      final leaves = repository.events
          .where((e) => e.eventType == 'screen_leave')
          .toList();
      expect(leaves.map((e) => e.screenName), [
        'home',
        'education-module',
        'lesson',
        'profile',
        'lesson',
        'education-module',
      ]);
      expect(leaves.map((e) => e.durationSeconds), [2, 3, 4, 5, 6, 7]);
      expect(leaves[4].lessonId, 'nursing-roles');
      expect(leaves[5].moduleId, 'nursing-fundamentals');
      expect(
        repository.events.where((e) => e.eventType == 'session_start'),
        hasLength(1),
      );
    },
  );
}
