using System.Text.Json;
using AsliApp.Domain.Analytics;
using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;
using System.Data;

namespace AsliApp.Api.Analytics;

public sealed class ActivityService(AppDbContext dbContext, ILogger<ActivityService> logger, IHostEnvironment environment)
{
    private static readonly HashSet<string> AllowedMetadataKeys = new(StringComparer.OrdinalIgnoreCase)
    {
        "source", "result", "positionSeconds", "scorePercentage", "platform",
    };

    public async Task<ActivityBatchResponse> RecordBatchAsync(
        Guid userId,
        ActivityBatchRequest request,
        CancellationToken cancellationToken)
    {
        for (var attempt = 0; ; attempt++)
        {
            await using var transaction = dbContext.Database.IsRelational()
                ? await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken)
                : null;
            try
            {
                var result = await RecordBatchCoreAsync(userId, request, cancellationToken);
                if (transaction is not null) await transaction.CommitAsync(cancellationToken);
                if (environment.IsDevelopment())
                    logger.LogInformation("Analytics batch persisted: {AcceptedCount} accepted, {DuplicateCount} duplicates.",
                        result.AcceptedCount, result.DuplicateCount);
                return result;
            }
            catch (Exception error) when (attempt < 2 && IsConcurrencyConflict(error))
            {
                if (transaction is not null) await transaction.RollbackAsync(cancellationToken);
                dbContext.ChangeTracker.Clear();
                if (environment.IsDevelopment()) logger.LogWarning("Analytics batch concurrency retry.");
            }
            catch (Exception error) when (error is DbUpdateException or SqlException)
            {
                // Do not include SQL parameters, payloads, identifiers or exception text.
                logger.LogError("Analytics persistence failed ({FailureType}).", error.GetType().Name);
                throw;
            }
        }
    }

    private static bool IsConcurrencyConflict(Exception error) =>
        (error as SqlException ?? error.InnerException as SqlException)?.Number is 1205 or 2601 or 2627;

    private async Task<ActivityBatchResponse> RecordBatchCoreAsync(
        Guid userId,
        ActivityBatchRequest request,
        CancellationToken cancellationToken)
    {
        var distinct = request.Events
            .GroupBy(item => item.ClientEventId)
            .Select(group => group.First())
            .ToArray();
        var ids = distinct.Select(item => item.ClientEventId).ToArray();
        var existingIds = await dbContext.UserActivityEvents
            .Where(item => ids.Contains(item.ClientEventId))
            .Select(item => item.ClientEventId)
            .ToHashSetAsync(cancellationToken);
        var accepted = distinct.Where(item => !existingIds.Contains(item.ClientEventId)).ToArray();
        var sessionIds = accepted.Select(item => item.SessionId).Distinct().ToArray();
        var sessions = await dbContext.AppSessions
            .Where(session => sessionIds.Contains(session.Id))
            .ToDictionaryAsync(session => session.Id, cancellationToken);

        foreach (var item in accepted.OrderBy(item => item.OccurredAtUtc))
        {
            if (item.ClientEventId == Guid.Empty || item.SessionId == Guid.Empty || item.OccurredAtUtc == default)
                throw new ArgumentException("Event/session IDs and occurrence time are required.");
            if (!TryParseEventType(item.EventType, out var eventType))
            {
                throw new ArgumentException($"Unsupported activity event type: {item.EventType}");
            }

            if (!sessions.TryGetValue(item.SessionId, out var session))
            {
                session = new AppSession
                {
                    Id = item.SessionId,
                    UserId = userId,
                    StartedAtUtc = item.OccurredAtUtc,
                    LastActivityAtUtc = item.OccurredAtUtc,
                };
                sessions.Add(session.Id, session);
                dbContext.AppSessions.Add(session);
            }
            else if (session.UserId != userId)
            {
                throw new ActivitySessionOwnershipException();
            }

            session.StartedAtUtc = session.StartedAtUtc <= item.OccurredAtUtc
                ? session.StartedAtUtc
                : item.OccurredAtUtc;
            session.LastActivityAtUtc = session.LastActivityAtUtc >= item.OccurredAtUtc
                ? session.LastActivityAtUtc
                : item.OccurredAtUtc;
            if (eventType == ActivityEventType.SessionEnd)
            {
                session.EndedAtUtc = session.EndedAtUtc > item.OccurredAtUtc ? session.EndedAtUtc : item.OccurredAtUtc;
                session.ActiveDurationSeconds = ActivityDurationCalculator.SessionDuration(
                    session.ActiveDurationSeconds,
                    item.DurationSeconds);
            }
            else if (eventType == ActivityEventType.ScreenLeave)
            {
                session.ActiveDurationSeconds = ActivityDurationCalculator.AddActiveSegment(
                    session.ActiveDurationSeconds,
                    item.DurationSeconds);
            }

            dbContext.UserActivityEvents.Add(new UserActivityEvent
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                SessionId = item.SessionId,
                EventType = eventType,
                ScreenName = CleanNonSensitive(item.ScreenName, 100),
                OccurredAtUtc = item.OccurredAtUtc,
                DurationSeconds = item.DurationSeconds,
                ModuleId = item.ModuleId,
                LessonId = item.LessonId,
                QuizId = item.QuizId,
                QuestionId = item.QuestionId,
                Target = CleanNonSensitive(item.Target, 200),
                MetadataJson = SanitizeMetadata(item.Metadata),
                ClientEventId = item.ClientEventId,
            });
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        foreach (var session in sessions.Values)
        {
            var events = dbContext.UserActivityEvents.Where(item => item.SessionId == session.Id);
            var segments = await events.Where(item => item.EventType == ActivityEventType.ScreenLeave)
                .SumAsync(item => (long?)item.DurationSeconds, cancellationToken) ?? 0;
            var reported = await events.Where(item => item.EventType == ActivityEventType.SessionEnd)
                .MaxAsync(item => item.DurationSeconds, cancellationToken) ?? 0;
            session.ActiveDurationSeconds = (int)Math.Min(7 * 86400, Math.Max(segments, reported));
        }
        await dbContext.SaveChangesAsync(cancellationToken);
        return new ActivityBatchResponse(
            accepted.Length,
            request.Events.Count - accepted.Length);
    }

    private static bool TryParseEventType(string value, out ActivityEventType result) =>
        Enum.TryParse(value.Replace("_", string.Empty), ignoreCase: true, out result) &&
        Enum.IsDefined(result) && !int.TryParse(value, out _);

    private static string? Clean(string? value, int maxLength)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed)
            ? null
            : trimmed[..Math.Min(trimmed.Length, maxLength)];
    }

    private static string? CleanNonSensitive(string? value, int maxLength)
    {
        var clean = Clean(value, maxLength);
        if (clean is null) return null;
        var normalized = clean.ToLowerInvariant();
        return clean.Contains('@') ||
               normalized.Contains("bearer ") ||
               normalized.Contains("password") ||
               normalized.Contains("token") ||
               normalized.Contains("verification code") ||
               normalized.Contains("reset code")
            ? null
            : clean;
    }

    private static string? SanitizeMetadata(IReadOnlyDictionary<string, string>? metadata)
    {
        if (metadata is null || metadata.Count == 0) return null;
        var safe = metadata
            .Where(pair => AllowedMetadataKeys.Contains(pair.Key))
            .GroupBy(pair => pair.Key, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .Take(10)
            .ToDictionary(
                pair => pair.Key,
                pair => CleanNonSensitive(pair.Value, 200) ?? string.Empty,
                StringComparer.OrdinalIgnoreCase);
        while (safe.Count > 0)
        {
            var json = JsonSerializer.Serialize(safe);
            if (json.Length <= 2000) return json;
            safe.Remove(safe.Keys.Last());
        }
        return null;
    }
}

public sealed class ActivitySessionOwnershipException : Exception;
