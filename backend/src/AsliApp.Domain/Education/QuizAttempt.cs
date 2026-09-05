using AsliApp.Domain.Users;

namespace AsliApp.Domain.Education;

public sealed class QuizAttempt
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid QuizId { get; set; }
    public int TotalQuestionCount { get; set; }
    public int CorrectCount { get; set; }
    public int IncorrectCount { get; set; }
    public decimal ScorePercentage { get; set; }
    public DateTimeOffset CompletedAtUtc { get; set; }

    public User User { get; set; } = null!;
    public Quiz Quiz { get; set; } = null!;
    public ICollection<QuizAttemptAnswer> Answers { get; set; } = [];
}
