final class UserActivityAnalytics {
  const UserActivityAnalytics({
    required this.userId,
    required this.displayName,
    required this.lastActiveAtUtc,
    required this.activeDurationSeconds,
    required this.sessionCount,
    required this.eventCount,
    required this.screens,
    required this.modules,
    required this.lessons,
    required this.quizzes,
    required this.timeline,
  });

  final String userId;
  final String displayName;
  final DateTime? lastActiveAtUtc;
  final int activeDurationSeconds;
  final int sessionCount;
  final int eventCount;
  final List<ActivityDuration> screens;
  final List<ActivityDuration> modules;
  final List<ActivityDuration> lessons;
  final List<QuizActivity> quizzes;
  final List<ActivityTimelineItem> timeline;
}

final class ActivityDuration {
  const ActivityDuration({
    required this.key,
    this.name,
    required this.durationSeconds,
  });
  final String key;
  final String? name;
  final int durationSeconds;
}

final class QuizActivity {
  const QuizActivity({
    required this.title,
    required this.attemptCount,
    required this.durationSeconds,
    this.averageScore,
    this.bestScore,
  });
  final String title;
  final int attemptCount;
  final int durationSeconds;
  final double? averageScore;
  final double? bestScore;
}

final class ActivityTimelineItem {
  const ActivityTimelineItem({
    required this.eventType,
    required this.occurredAtUtc,
    this.screenName,
    this.target,
  });
  final String eventType;
  final DateTime occurredAtUtc;
  final String? screenName;
  final String? target;
}

typedef AnalyticsRange = ({String userId, DateTime fromUtc, DateTime toUtc});
