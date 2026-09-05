namespace AsliApp.Domain.Education;

public sealed class QuizOption
{
    public Guid Id { get; set; }
    public Guid QuizQuestionId { get; set; }
    public string Text { get; set; } = string.Empty;
    public bool IsCorrect { get; set; }
    public int Order { get; set; }
    public DateTimeOffset CreatedAtUtc { get; set; }
    public DateTimeOffset UpdatedAtUtc { get; set; }

    public QuizQuestion QuizQuestion { get; set; } = null!;
}
