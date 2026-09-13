using System.ComponentModel.DataAnnotations;

namespace AsliApp.Api.Analytics;

public sealed record ActivityEventRequest(
    Guid ClientEventId,
    Guid SessionId,
    [Required, MaxLength(40)] string EventType,
    [MaxLength(100)] string? ScreenName,
    DateTimeOffset OccurredAtUtc,
    [Range(0, 86400)] int? DurationSeconds,
    Guid? ModuleId,
    Guid? LessonId,
    Guid? QuizId,
    Guid? QuestionId,
    [MaxLength(200)] string? Target,
    IReadOnlyDictionary<string, string>? Metadata);

public sealed record ActivityBatchRequest(
    [Required, MinLength(1), MaxLength(100)] IReadOnlyList<ActivityEventRequest> Events);

public sealed record ActivityBatchResponse(int AcceptedCount, int DuplicateCount);

public sealed record UserActivityListItemResponse(
    Guid UserId,
    string DisplayName,
    DateTimeOffset? LastActiveAtUtc,
    int ActiveDurationSeconds,
    int SessionCount);

public sealed record UserActivitySummaryResponse(
    Guid UserId,
    string DisplayName,
    DateTimeOffset? LastActiveAtUtc,
    int ActiveDurationSeconds,
    int SessionCount,
    int EventCount);

public sealed record ActivityDurationResponse(
    string Key,
    string? Name,
    int DurationSeconds);

public sealed record ActivityTimelineItemResponse(
    Guid Id,
    string EventType,
    string? ScreenName,
    DateTimeOffset OccurredAtUtc,
    int? DurationSeconds,
    Guid? ModuleId,
    Guid? LessonId,
    Guid? QuizId,
    Guid? QuestionId,
    string? Target,
    IReadOnlyDictionary<string, string>? Metadata);

public sealed record QuizActivityResponse(
    Guid QuizId,
    string QuizTitle,
    int AttemptCount,
    int DurationSeconds,
    decimal? AverageScorePercentage,
    decimal? BestScorePercentage,
    DateTimeOffset? LastCompletedAtUtc);

public sealed record AnalyticsDateRange(DateTimeOffset FromUtc, DateTimeOffset ToUtc);
