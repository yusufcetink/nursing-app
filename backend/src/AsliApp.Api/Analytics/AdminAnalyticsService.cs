using System.Text.Json;
using AsliApp.Domain.Analytics;
using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AsliApp.Api.Analytics;

public sealed class AdminAnalyticsService(AppDbContext dbContext, TimeProvider timeProvider)
{
    public async Task<IReadOnlyList<UserActivityListItemResponse>> GetUsersAsync(
        DateTimeOffset? fromUtc,
        DateTimeOffset? toUtc,
        CancellationToken cancellationToken)
    {
        var range = Range(fromUtc, toUtc);
        var users = await dbContext.Users.AsNoTracking()
            .Select(user => new UserActivityListItemResponse(
                user.Id,
                user.FirstName + " " + user.LastName,
                user.ActivityEvents.Where(item => item.OccurredAtUtc >= range.FromUtc && item.OccurredAtUtc <= range.ToUtc)
                    .Max(item => (DateTimeOffset?)item.OccurredAtUtc),
                user.ActivityEvents.Where(item => item.OccurredAtUtc >= range.FromUtc && item.OccurredAtUtc <= range.ToUtc && item.EventType == ActivityEventType.ScreenLeave)
                    .Sum(item => item.DurationSeconds ?? 0),
                user.ActivityEvents.Where(item => item.OccurredAtUtc >= range.FromUtc && item.OccurredAtUtc <= range.ToUtc).Select(item => item.SessionId).Distinct().Count()))
            .ToListAsync(cancellationToken);
        return users.OrderByDescending(item => item.LastActiveAtUtc).ToArray();
    }

    public async Task<UserActivitySummaryResponse?> GetSummaryAsync(
        Guid userId,
        DateTimeOffset? fromUtc,
        DateTimeOffset? toUtc,
        CancellationToken cancellationToken)
    {
        var range = Range(fromUtc, toUtc);
        return await dbContext.Users.AsNoTracking()
            .Where(user => user.Id == userId)
            .Select(user => new UserActivitySummaryResponse(
                user.Id,
                user.FirstName + " " + user.LastName,
                user.ActivityEvents.Where(item => item.OccurredAtUtc >= range.FromUtc && item.OccurredAtUtc <= range.ToUtc)
                    .Max(item => (DateTimeOffset?)item.OccurredAtUtc),
                user.ActivityEvents.Where(item => item.OccurredAtUtc >= range.FromUtc && item.OccurredAtUtc <= range.ToUtc && item.EventType == ActivityEventType.ScreenLeave)
                    .Sum(item => item.DurationSeconds ?? 0),
                user.ActivityEvents.Where(item => item.OccurredAtUtc >= range.FromUtc && item.OccurredAtUtc <= range.ToUtc).Select(item => item.SessionId).Distinct().Count(),
                user.ActivityEvents.Count(item => item.OccurredAtUtc >= range.FromUtc && item.OccurredAtUtc <= range.ToUtc)))
            .SingleOrDefaultAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<ActivityTimelineItemResponse>> GetTimelineAsync(
        Guid userId,
        DateTimeOffset? fromUtc,
        DateTimeOffset? toUtc,
        int take,
        CancellationToken cancellationToken)
    {
        var range = Range(fromUtc, toUtc);
        var items = await Events(userId, range)
            .OrderByDescending(item => item.OccurredAtUtc)
            .Take(Math.Clamp(take, 1, 500))
            .ToListAsync(cancellationToken);
        return items.Select(item => new ActivityTimelineItemResponse(
            item.Id,
            ToSnakeCase(item.EventType),
            item.ScreenName,
            item.OccurredAtUtc,
            item.DurationSeconds,
            item.ModuleId,
            item.LessonId,
            item.QuizId,
            item.QuestionId,
            item.Target,
            DeserializeMetadata(item.MetadataJson))).ToArray();
    }

    public async Task<IReadOnlyList<ActivityDurationResponse>> GetScreenDurationsAsync(
        Guid userId, DateTimeOffset? fromUtc, DateTimeOffset? toUtc, CancellationToken cancellationToken)
    {
        var range = Range(fromUtc, toUtc);
        var durations = await Events(userId, range)
            .Where(item => item.EventType == ActivityEventType.ScreenLeave && item.ScreenName != null && item.DurationSeconds != null)
            .GroupBy(item => item.ScreenName!)
            .Select(group => new ActivityDurationResponse(group.Key, group.Key, group.Sum(item => item.DurationSeconds!.Value)))
            .ToListAsync(cancellationToken);
        return durations.OrderByDescending(item => item.DurationSeconds).ToArray();
    }

    public async Task<IReadOnlyList<ActivityDurationResponse>> GetModuleDurationsAsync(
        Guid userId, DateTimeOffset? fromUtc, DateTimeOffset? toUtc, CancellationToken cancellationToken)
    {
        var range = Range(fromUtc, toUtc);
        var durations = await Events(userId, range)
            .Where(item => item.EventType == ActivityEventType.ScreenLeave && item.ModuleId != null && item.DurationSeconds != null)
            .GroupBy(item => item.ModuleId!.Value)
            .Select(group => new { Id = group.Key, Duration = group.Sum(item => item.DurationSeconds!.Value) })
            .ToListAsync(cancellationToken);
        var ids = durations.Select(item => item.Id).ToArray();
        var names = await dbContext.EducationModules.IgnoreQueryFilters().AsNoTracking()
            .Where(module => ids.Contains(module.Id))
            .ToDictionaryAsync(module => module.Id, module => module.Title, cancellationToken);
        return durations.OrderByDescending(item => item.Duration)
            .Select(item => new ActivityDurationResponse(item.Id.ToString(), names.GetValueOrDefault(item.Id), item.Duration)).ToArray();
    }

    public async Task<IReadOnlyList<ActivityDurationResponse>> GetLessonDurationsAsync(
        Guid userId, DateTimeOffset? fromUtc, DateTimeOffset? toUtc, CancellationToken cancellationToken)
    {
        var range = Range(fromUtc, toUtc);
        var durations = await Events(userId, range)
            .Where(item => item.EventType == ActivityEventType.ScreenLeave && item.LessonId != null && item.DurationSeconds != null)
            .GroupBy(item => item.LessonId!.Value)
            .Select(group => new { Id = group.Key, Duration = group.Sum(item => item.DurationSeconds!.Value) })
            .ToListAsync(cancellationToken);
        var ids = durations.Select(item => item.Id).ToArray();
        var names = await dbContext.Lessons.IgnoreQueryFilters().AsNoTracking()
            .Where(lesson => ids.Contains(lesson.Id))
            .ToDictionaryAsync(lesson => lesson.Id, lesson => lesson.Title, cancellationToken);
        return durations.OrderByDescending(item => item.Duration)
            .Select(item => new ActivityDurationResponse(item.Id.ToString(), names.GetValueOrDefault(item.Id), item.Duration)).ToArray();
    }

    public async Task<IReadOnlyList<QuizActivityResponse>> GetQuizStatisticsAsync(
        Guid userId, DateTimeOffset? fromUtc, DateTimeOffset? toUtc, CancellationToken cancellationToken)
    {
        var range = Range(fromUtc, toUtc);
        var durations = await Events(userId, range)
            .Where(item => item.EventType == ActivityEventType.QuizComplete && item.QuizId != null && item.DurationSeconds != null)
            .GroupBy(item => item.QuizId!.Value)
            .Select(group => new { QuizId = group.Key, Duration = group.Sum(item => item.DurationSeconds!.Value) })
            .ToDictionaryAsync(item => item.QuizId, item => item.Duration, cancellationToken);
        var attempts = await dbContext.QuizAttempts.AsNoTracking()
            .Where(item => item.UserId == userId && item.CompletedAtUtc >= range.FromUtc && item.CompletedAtUtc <= range.ToUtc)
            .GroupBy(item => new { item.QuizId, item.Quiz.Title })
            .Select(group => new QuizActivityResponse(
                group.Key.QuizId,
                group.Key.Title,
                group.Count(),
                0,
                group.Average(item => item.ScorePercentage),
                group.Max(item => item.ScorePercentage),
                group.Max(item => (DateTimeOffset?)item.CompletedAtUtc)))
            .ToListAsync(cancellationToken);
        return attempts
            .Select(item => item with { DurationSeconds = durations.GetValueOrDefault(item.QuizId) })
            .OrderByDescending(item => item.LastCompletedAtUtc)
            .ToArray();
    }

    private IQueryable<UserActivityEvent> Events(Guid userId, AnalyticsDateRange range) =>
        dbContext.UserActivityEvents.AsNoTracking().Where(item =>
            item.UserId == userId && item.OccurredAtUtc >= range.FromUtc && item.OccurredAtUtc <= range.ToUtc);

    private AnalyticsDateRange Range(DateTimeOffset? fromUtc, DateTimeOffset? toUtc)
    {
        var to = toUtc ?? timeProvider.GetUtcNow();
        var from = fromUtc ?? to.AddDays(-30);
        if (from > to) throw new ArgumentException("fromUtc cannot be after toUtc.");
        return new(from, to);
    }

    private static IReadOnlyDictionary<string, string>? DeserializeMetadata(string? json) =>
        json is null ? null : JsonSerializer.Deserialize<Dictionary<string, string>>(json);

    private static string ToSnakeCase(ActivityEventType value) =>
        string.Concat(value.ToString().Select((character, index) =>
            char.IsUpper(character) && index > 0 ? $"_{char.ToLowerInvariant(character)}" : char.ToLowerInvariant(character).ToString()));
}
