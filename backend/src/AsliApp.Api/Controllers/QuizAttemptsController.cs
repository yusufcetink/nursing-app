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
    [HttpGet("quizzes/{quizId:guid}/attempt")]
    public Task<IActionResult> Get(Guid quizId, CancellationToken cancellationToken) =>
        GetOrStart(quizId, false, cancellationToken);

    [HttpPost("quizzes/{quizId:guid}/start")]
    public Task<IActionResult> Start(Guid quizId, CancellationToken cancellationToken) =>
        GetOrStart(quizId, true, cancellationToken);

    private async Task<IActionResult> GetOrStart(Guid quizId, bool start, CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue("sub"), out var userId)) return Unauthorized();
        var outcome = await educationService.GetQuizAttemptAsync(userId, quizId, start, cancellationToken);
        if (outcome.StatusCode == 403)
            return StatusCode(403, new ProblemDetails
            {
                Status = 403,
                Title = "Complete the lesson before starting a quiz.",
                Extensions = { ["code"] = "lesson_not_completed" },
            });
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
