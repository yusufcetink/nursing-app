namespace AsliApp.Domain.Education;

public sealed class QuizAttemptAnswer
{
    public Guid Id { get; set; }
    public Guid QuizAttemptId { get; set; }
    public Guid QuizQuestionId { get; set; }
    public Guid SelectedOptionId { get; set; }
    public bool IsCorrect { get; set; }

    public QuizAttempt QuizAttempt { get; set; } = null!;
    public QuizQuestion QuizQuestion { get; set; } = null!;
    public QuizOption SelectedOption { get; set; } = null!;
}
