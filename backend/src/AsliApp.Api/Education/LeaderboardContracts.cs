namespace AsliApp.Api.Education;

public sealed record LeaderboardEntryResponse(
    int Rank, string DisplayName, string? AvatarUrl, int TotalCorrectAnswers,
    int TotalQuestionCount, int CompletedQuizCount, decimal AccuracyPercentage,
    bool IsCurrentUser);

public sealed record LeaderboardResponse(
    string Period, Guid? CourseId, string? CourseName, int? CourseQuizCount,
    int TotalUsers, int Offset, int Limit,
    IReadOnlyList<LeaderboardEntryResponse> Entries,
    LeaderboardEntryResponse? CurrentUser);

public sealed record LeaderboardCourseResponse(Guid Id, string Title, int QuizCount);
