using System.ComponentModel.DataAnnotations;

namespace AsliApp.Api.Education;

public sealed record EducationModuleSummaryResponse(
    Guid Id,
    string Title,
    string Description,
    int Order,
    int LessonCount,
    DateTimeOffset UpdatedAtUtc);

public sealed record EducationModuleResponse(
    Guid Id,
    string Title,
    string Description,
    int Order,
    IReadOnlyList<LessonSummaryResponse> Lessons,
    DateTimeOffset UpdatedAtUtc);

public sealed record LessonSummaryResponse(
    Guid Id,
    string Title,
    string Description,
    int EstimatedDurationMinutes,
    int Order);

public sealed record LessonResponse(
    Guid Id,
    Guid EducationModuleId,
    string Title,
    string Description,
    int EstimatedDurationMinutes,
    int Order,
    Guid? QuizId,
    IReadOnlyList<LessonContentBlockResponse> Blocks,
    DateTimeOffset UpdatedAtUtc);

public sealed record LessonMediaResponse(
    Guid Id,
    Guid LessonId,
    string OriginalFileName,
    string ContentType,
    string MediaType,
    long SizeBytes,
    int SortOrder);

public sealed record LessonContentBlockResponse(
    Guid Id,
    Guid LessonId,
    string BlockType,
    string? TextContent,
    LessonMediaResponse? Media,
    int SortOrder);

public sealed record StudentQuizResponse(
    Guid Id,
    Guid LessonId,
    string Title,
    IReadOnlyList<StudentQuizQuestionResponse> Questions,
    DateTimeOffset UpdatedAtUtc);

public sealed record StudentQuizQuestionResponse(
    Guid Id,
    string Prompt,
    int Order,
    IReadOnlyList<StudentQuizOptionResponse> Options);

public sealed record StudentQuizOptionResponse(
    Guid Id,
    string Text,
    int Order);

public sealed record QuizSubmissionRequest(
    [Required, MinLength(1)] IReadOnlyList<QuizAnswerRequest> Answers);

public sealed record QuizAnswerRequest(
    Guid QuestionId,
    Guid SelectedOptionId);

public sealed record QuizSubmissionResponse(
    Guid AttemptId,
    Guid QuizId,
    int TotalQuestionCount,
    int CorrectCount,
    int IncorrectCount,
    decimal SuccessPercentage,
    DateTimeOffset CompletedAtUtc);

public sealed record LessonCompletionResponse(
    Guid LessonId,
    Guid EducationModuleId,
    DateTimeOffset CompletedAtUtc);

public sealed record ProgressResponse(
    IReadOnlyList<CompletedLessonResponse> CompletedLessons);

public sealed record CompletedLessonResponse(
    Guid LessonId,
    Guid EducationModuleId,
    DateTimeOffset CompletedAtUtc);

public sealed record QuizHistoryItemResponse(
    Guid AttemptId,
    Guid QuizId,
    Guid LessonId,
    string QuizTitle,
    string LessonTitle,
    int TotalQuestionCount,
    int CorrectCount,
    int IncorrectCount,
    decimal SuccessPercentage,
    DateTimeOffset CompletedAtUtc);

public sealed record QuizHistoryDetailResponse(
    Guid AttemptId,
    Guid QuizId,
    Guid LessonId,
    string QuizTitle,
    string LessonTitle,
    int TotalQuestionCount,
    int CorrectCount,
    int IncorrectCount,
    decimal SuccessPercentage,
    DateTimeOffset CompletedAtUtc);

public sealed record ContentMutationResponse(Guid Id);

public sealed record ContentEducationModuleSummaryResponse(
    Guid Id,
    string Title,
    string Description,
    int Order,
    bool IsPublished,
    int LessonCount,
    DateTimeOffset UpdatedAtUtc);

public sealed record ContentEducationModuleResponse(
    Guid Id,
    string Title,
    string Description,
    int Order,
    bool IsPublished,
    IReadOnlyList<ContentLessonSummaryResponse> Lessons,
    DateTimeOffset UpdatedAtUtc);

public sealed record ContentLessonSummaryResponse(
    Guid Id,
    string Title,
    string Description,
    int EstimatedDurationMinutes,
    int Order,
    bool IsPublished);

public sealed record ContentLessonResponse(
    Guid Id,
    Guid EducationModuleId,
    string Title,
    string Description,
    int EstimatedDurationMinutes,
    int Order,
    bool IsPublished,
    Guid? QuizId,
    IReadOnlyList<LessonContentBlockResponse> Blocks,
    DateTimeOffset UpdatedAtUtc);

public sealed class LessonMediaUploadRequest
{
    [Required]
    public IFormFile? File { get; init; }

    [Range(0, int.MaxValue)]
    public int SortOrder { get; init; }
}

public sealed record LessonContentBlockWriteRequest(
    [Required] string BlockType,
    string? TextContent,
    Guid? MediaId,
    [Range(0, int.MaxValue)] int SortOrder);

public sealed record LessonContentBlockReorderRequest(
    [Required, MinLength(1)] IReadOnlyList<LessonContentBlockOrderRequest> Blocks);

public sealed record LessonContentBlockOrderRequest(
    Guid BlockId,
    [Range(0, int.MaxValue)] int SortOrder);

public sealed record ContentQuizResponse(
    Guid Id,
    Guid LessonId,
    string Title,
    bool IsPublished,
    IReadOnlyList<ContentQuizQuestionResponse> Questions,
    DateTimeOffset UpdatedAtUtc);

public sealed record ContentQuizQuestionResponse(
    Guid Id,
    string Prompt,
    int Order,
    IReadOnlyList<ContentQuizOptionResponse> Options);

public sealed record ContentQuizOptionResponse(
    Guid Id,
    string Text,
    bool IsCorrect,
    int Order);

public sealed record EducationModuleWriteRequest(
    [Required, MaxLength(200)] string Title,
    [Required, MaxLength(1000)] string Description,
    [Range(0, int.MaxValue)] int Order,
    bool IsPublished);

public sealed record LessonWriteRequest(
    [Required, MaxLength(200)] string Title,
    [Required, MaxLength(500)] string Description,
    [Range(1, int.MaxValue)] int EstimatedDurationMinutes,
    [Range(0, int.MaxValue)] int Order,
    bool IsPublished);

public sealed record QuizWriteRequest(
    [Required, MaxLength(200)] string Title,
    bool IsPublished);

public sealed record QuizQuestionWriteRequest(
    [Required, MaxLength(1000)] string Prompt,
    [Range(0, int.MaxValue)] int Order);

public sealed record QuizOptionWriteRequest(
    [Required, MaxLength(500)] string Text,
    bool IsCorrect,
    [Range(0, int.MaxValue)] int Order);
