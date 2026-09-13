using AsliApp.Api.Analytics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AsliApp.Api.Controllers;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("api/admin/analytics")]
public sealed class AdminAnalyticsController(AdminAnalyticsService analyticsService) : ControllerBase
{
    [HttpGet("users")]
    public Task<IReadOnlyList<UserActivityListItemResponse>> Users(
        DateTimeOffset? fromUtc, DateTimeOffset? toUtc, CancellationToken cancellationToken) =>
        analyticsService.GetUsersAsync(fromUtc, toUtc, cancellationToken);

    [HttpGet("users/{userId:guid}")]
    public async Task<ActionResult<UserActivitySummaryResponse>> Summary(
        Guid userId, DateTimeOffset? fromUtc, DateTimeOffset? toUtc, CancellationToken cancellationToken)
    {
        var result = await analyticsService.GetSummaryAsync(userId, fromUtc, toUtc, cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpGet("users/{userId:guid}/events")]
    public Task<IReadOnlyList<ActivityTimelineItemResponse>> Timeline(
        Guid userId, DateTimeOffset? fromUtc, DateTimeOffset? toUtc, int take = 200, CancellationToken cancellationToken = default) =>
        analyticsService.GetTimelineAsync(userId, fromUtc, toUtc, take, cancellationToken);

    [HttpGet("users/{userId:guid}/durations/screens")]
    public Task<IReadOnlyList<ActivityDurationResponse>> Screens(Guid userId, DateTimeOffset? fromUtc, DateTimeOffset? toUtc, CancellationToken cancellationToken) =>
        analyticsService.GetScreenDurationsAsync(userId, fromUtc, toUtc, cancellationToken);

    [HttpGet("users/{userId:guid}/durations/modules")]
    public Task<IReadOnlyList<ActivityDurationResponse>> Modules(Guid userId, DateTimeOffset? fromUtc, DateTimeOffset? toUtc, CancellationToken cancellationToken) =>
        analyticsService.GetModuleDurationsAsync(userId, fromUtc, toUtc, cancellationToken);

    [HttpGet("users/{userId:guid}/durations/lessons")]
    public Task<IReadOnlyList<ActivityDurationResponse>> Lessons(Guid userId, DateTimeOffset? fromUtc, DateTimeOffset? toUtc, CancellationToken cancellationToken) =>
        analyticsService.GetLessonDurationsAsync(userId, fromUtc, toUtc, cancellationToken);

    [HttpGet("users/{userId:guid}/quizzes")]
    public Task<IReadOnlyList<QuizActivityResponse>> Quizzes(Guid userId, DateTimeOffset? fromUtc, DateTimeOffset? toUtc, CancellationToken cancellationToken) =>
        analyticsService.GetQuizStatisticsAsync(userId, fromUtc, toUtc, cancellationToken);
}
