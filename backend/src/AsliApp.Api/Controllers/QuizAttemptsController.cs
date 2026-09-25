using System.Security.Claims;
using AsliApp.Api.Education;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AsliApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/education")]
public sealed class QuizAttemptsController(EducationService educationService) : ControllerBase
{
    [HttpGet("lessons/{lessonId:guid}/quiz/attempt")]
    public Task<IActionResult> Get(Guid lessonId, CancellationToken cancellationToken) =>
        GetOrStart(lessonId, false, cancellationToken);

    [HttpPost("lessons/{lessonId:guid}/quiz/start")]
    public Task<IActionResult> Start(Guid lessonId, CancellationToken cancellationToken) =>
        GetOrStart(lessonId, true, cancellationToken);

    private async Task<IActionResult> GetOrStart(Guid lessonId, bool start, CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue("sub"), out var userId)) return Unauthorized();
        var outcome = await educationService.GetQuizAttemptAsync(userId, lessonId, start, cancellationToken);
        return StatusCode(outcome.StatusCode, outcome.Response);
    }

    [HttpPost("quiz-attempts/{attemptId:guid}/answers")]
    public async Task<IActionResult> Answer(Guid attemptId, QuizAnswerRequest request, CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue("sub"), out var userId)) return Unauthorized();
        var outcome = await educationService.SaveQuizAnswerAsync(userId, attemptId, request, cancellationToken);
        return StatusCode(outcome.StatusCode, outcome.Response);
    }

    [HttpDelete("admin/users/{userId:guid}/quizzes/{quizId:guid}/attempt")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Reset(Guid userId, Guid quizId, CancellationToken cancellationToken)
    {
        await educationService.ResetQuizAttemptAsync(userId, quizId, cancellationToken);
        return NoContent();
    }
}
