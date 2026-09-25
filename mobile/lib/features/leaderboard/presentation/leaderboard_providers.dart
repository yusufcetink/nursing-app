import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/leaderboard/data/leaderboard_repository.dart';

typedef LeaderboardSelection = ({String period, String? courseId, int offset});

final homeLeaderboardProvider = FutureProvider<LeaderboardData>(
  (ref) =>
      ref.watch(leaderboardRepositoryProvider).get(period: 'weekly', limit: 3),
);

final leaderboardCoursesProvider = FutureProvider<List<LeaderboardCourse>>(
  (ref) => ref.watch(leaderboardRepositoryProvider).courses(),
);

final leaderboardProvider =
    FutureProvider.family<LeaderboardData, LeaderboardSelection>(
      (ref, selection) => ref
          .watch(leaderboardRepositoryProvider)
          .get(
            period: selection.period,
            courseId: selection.courseId,
            offset: selection.offset,
          ),
    );
