final class ActivityEvent {
  const ActivityEvent({
    required this.clientEventId,
    required this.sessionId,
    required this.eventType,
    required this.occurredAtUtc,
    this.screenName,
    this.durationSeconds,
    this.moduleId,
    this.lessonId,
    this.quizId,
    this.questionId,
    this.target,
    this.metadata,
  });

  final String clientEventId;
  final String sessionId;
  final String eventType;
  final DateTime occurredAtUtc;
  final String? screenName;
  final int? durationSeconds;
  final String? moduleId;
  final String? lessonId;
  final String? quizId;
  final String? questionId;
  final String? target;
  final Map<String, String>? metadata;

  Map<String, Object?> toJson() => {
    'clientEventId': clientEventId,
    'sessionId': sessionId,
    'eventType': eventType,
    'screenName': screenName,
    'occurredAtUtc': occurredAtUtc.toUtc().toIso8601String(),
    'durationSeconds': durationSeconds,
    'moduleId': moduleId,
    'lessonId': lessonId,
    'quizId': quizId,
    'questionId': questionId,
    'target': target,
    'metadata': metadata,
  };
}
