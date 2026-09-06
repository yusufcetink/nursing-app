using AsliApp.Api.Education;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AsliApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/education")]
public sealed class EducationController(EducationService educationService) : ControllerBase
{
    [HttpGet("modules")]
    public async Task<ActionResult<IReadOnlyList<EducationModuleSummaryResponse>>> GetModules(
        CancellationToken cancellationToken)
    {
        return Ok(await educationService.GetModulesAsync(cancellationToken));
    }

    [HttpGet("modules/{id:guid}")]
    public async Task<ActionResult<EducationModuleResponse>> GetModule(
        Guid id,
        CancellationToken cancellationToken)
    {
        var module = await educationService.GetModuleAsync(id, cancellationToken);
        return module is null ? NotFound() : Ok(module);
    }

    [HttpGet("lessons/{id:guid}")]
    public async Task<ActionResult<LessonResponse>> GetLesson(
        Guid id,
        CancellationToken cancellationToken)
    {
        var lesson = await educationService.GetLessonAsync(id, cancellationToken);
        return lesson is null ? NotFound() : Ok(lesson);
    }

    [HttpGet("lessons/{id:guid}/quiz")]
    public async Task<ActionResult<StudentQuizResponse>> GetLessonQuiz(
        Guid id,
        CancellationToken cancellationToken)
    {
        var quiz = await educationService.GetLessonQuizAsync(id, cancellationToken);
        return quiz is null ? NotFound() : Ok(quiz);
    }

    [HttpPost("lessons/{id:guid}/quiz/submit")]
    public async Task<ActionResult<QuizSubmissionResponse>> SubmitLessonQuiz(
        Guid id,
        QuizSubmissionRequest request,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue("sub"), out var userId))
        {
            return Unauthorized();
        }
        var outcome = await educationService.SubmitLessonQuizAsync(
            userId,
            id,
            request,
            cancellationToken);
        return outcome.Status switch
        {
            QuizSubmissionStatus.Success => Ok(outcome.Response),
            QuizSubmissionStatus.NotFound => NotFound(),
            _ => BadRequest(new ProblemDetails
            {
                Title = "Quiz answers are invalid.",
                Status = StatusCodes.Status400BadRequest,
            }),
        };
    }

    [HttpPut("lessons/{id:guid}/progress")]
    public async Task<ActionResult<LessonCompletionResponse>> CompleteLesson(
        Guid id,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirstValue("sub"), out var userId))
        {
            return Unauthorized();
        }

        var progress = await educationService.CompleteLessonAsync(
            userId,
            id,
            cancellationToken);
        return progress is null ? NotFound() : Ok(progress);
    }
}

[ApiController]
[Authorize]
[Route("api/profile")]
public sealed class ProfileController(EducationService educationService) : ControllerBase
{
    [HttpGet("progress")]
    public async Task<ActionResult<ProgressResponse>> GetProgress(
        CancellationToken cancellationToken)
    {
        return TryGetUserId(out var userId)
            ? Ok(await educationService.GetProgressAsync(userId, cancellationToken))
            : Unauthorized();
    }

    [HttpGet("quiz-history")]
    public async Task<ActionResult<IReadOnlyList<QuizHistoryItemResponse>>> GetQuizHistory(
        CancellationToken cancellationToken)
    {
        return TryGetUserId(out var userId)
            ? Ok(await educationService.GetQuizHistoryAsync(userId, cancellationToken))
            : Unauthorized();
    }

    [HttpGet("quiz-history/{attemptId:guid}")]
    public async Task<ActionResult<QuizHistoryDetailResponse>> GetQuizHistoryDetail(
        Guid attemptId,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(out var userId))
        {
            return Unauthorized();
        }

        var result = await educationService.GetQuizHistoryDetailAsync(
            userId,
            attemptId,
            cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }

    private bool TryGetUserId(out Guid userId) =>
        Guid.TryParse(User.FindFirstValue("sub"), out userId);
}

[ApiController]
[Authorize(Roles = "ContentEditor,Admin")]
[Route("api/education")]
public sealed class EducationContentController(EducationService educationService) : ControllerBase
{
    [HttpGet("content/modules")]
    public async Task<ActionResult<IReadOnlyList<ContentEducationModuleSummaryResponse>>>
        GetContentModules(CancellationToken cancellationToken)
    {
        return Ok(await educationService.GetContentModulesAsync(cancellationToken));
    }

    [HttpGet("content/modules/{id:guid}")]
    public async Task<ActionResult<ContentEducationModuleResponse>> GetContentModule(
        Guid id,
        CancellationToken cancellationToken)
    {
        var module = await educationService.GetContentModuleAsync(id, cancellationToken);
        return module is null ? NotFound() : Ok(module);
    }

    [HttpGet("content/lessons/{id:guid}")]
    public async Task<ActionResult<ContentLessonResponse>> GetContentLesson(
        Guid id,
        CancellationToken cancellationToken)
    {
        var lesson = await educationService.GetContentLessonAsync(id, cancellationToken);
        return lesson is null ? NotFound() : Ok(lesson);
    }

    [HttpGet("content/lessons/{lessonId:guid}/quiz")]
    public async Task<ActionResult<ContentQuizResponse>> GetContentQuiz(
        Guid lessonId,
        CancellationToken cancellationToken)
    {
        var quiz = await educationService.GetContentQuizAsync(lessonId, cancellationToken);
        return quiz is null ? NotFound() : Ok(quiz);
    }

    [HttpPost("modules")]
    public async Task<ActionResult<ContentMutationResponse>> CreateModule(
        EducationModuleWriteRequest request,
        CancellationToken cancellationToken)
    {
        var id = await educationService.CreateModuleAsync(request, cancellationToken);
        return StatusCode(StatusCodes.Status201Created, new ContentMutationResponse(id));
    }

    [HttpPut("modules/{id:guid}")]
    public async Task<IActionResult> UpdateModule(
        Guid id,
        EducationModuleWriteRequest request,
        CancellationToken cancellationToken)
    {
        return await educationService.UpdateModuleAsync(id, request, cancellationToken)
            ? NoContent()
            : NotFound();
    }

    [HttpPost("modules/{moduleId:guid}/lessons")]
    public async Task<ActionResult<ContentMutationResponse>> CreateLesson(
        Guid moduleId,
        LessonWriteRequest request,
        CancellationToken cancellationToken)
    {
        var id = await educationService.CreateLessonAsync(moduleId, request, cancellationToken);
        return id is null
            ? NotFound()
            : StatusCode(StatusCodes.Status201Created, new ContentMutationResponse(id.Value));
    }

    [HttpPut("lessons/{id:guid}")]
    public async Task<IActionResult> UpdateLesson(
        Guid id,
        LessonWriteRequest request,
        CancellationToken cancellationToken)
    {
        return await educationService.UpdateLessonAsync(id, request, cancellationToken)
            ? NoContent()
            : NotFound();
    }

    [HttpPost("lessons/{lessonId:guid}/quiz")]
    public async Task<ActionResult<ContentMutationResponse>> CreateQuiz(
        Guid lessonId,
        QuizWriteRequest request,
        CancellationToken cancellationToken)
    {
        var id = await educationService.CreateQuizAsync(lessonId, request, cancellationToken);
        return id is null
            ? BadRequest()
            : StatusCode(StatusCodes.Status201Created, new ContentMutationResponse(id.Value));
    }

    [HttpPut("quizzes/{id:guid}")]
    public async Task<IActionResult> UpdateQuiz(
        Guid id,
        QuizWriteRequest request,
        CancellationToken cancellationToken)
    {
        return await educationService.UpdateQuizAsync(id, request, cancellationToken) switch
        {
            QuizUpdateStatus.Success => NoContent(),
            QuizUpdateStatus.Invalid => BadRequest(new ProblemDetails
            {
                Title = "A published quiz requires questions with exactly four options and one correct answer.",
                Status = StatusCodes.Status400BadRequest,
            }),
            _ => NotFound(),
        };
    }

    [HttpPost("quizzes/{quizId:guid}/questions")]
    public async Task<ActionResult<ContentMutationResponse>> CreateQuestion(
        Guid quizId,
        QuizQuestionWriteRequest request,
        CancellationToken cancellationToken)
    {
        var id = await educationService.CreateQuestionAsync(quizId, request, cancellationToken);
        return id is null
            ? NotFound()
            : StatusCode(StatusCodes.Status201Created, new ContentMutationResponse(id.Value));
    }

    [HttpPut("questions/{id:guid}")]
    public async Task<IActionResult> UpdateQuestion(
        Guid id,
        QuizQuestionWriteRequest request,
        CancellationToken cancellationToken)
    {
        return await educationService.UpdateQuestionAsync(id, request, cancellationToken)
            ? NoContent()
            : NotFound();
    }

    [HttpPost("questions/{questionId:guid}/options")]
    public async Task<ActionResult<ContentMutationResponse>> CreateOption(
        Guid questionId,
        QuizOptionWriteRequest request,
        CancellationToken cancellationToken)
    {
        var id = await educationService.CreateOptionAsync(questionId, request, cancellationToken);
        return id is null
            ? NotFound()
            : StatusCode(StatusCodes.Status201Created, new ContentMutationResponse(id.Value));
    }

    [HttpPut("options/{id:guid}")]
    public async Task<IActionResult> UpdateOption(
        Guid id,
        QuizOptionWriteRequest request,
        CancellationToken cancellationToken)
    {
        return await educationService.UpdateOptionAsync(id, request, cancellationToken)
            ? NoContent()
            : NotFound();
    }
}
