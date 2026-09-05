namespace AsliApp.Domain.Education;

public sealed class Quiz
{
    public Guid Id { get; set; }
    public Guid LessonId { get; set; }
    public string Title { get; set; } = string.Empty;
    public bool IsPublished { get; set; }
    public DateTimeOffset CreatedAtUtc { get; set; }
    public DateTimeOffset UpdatedAtUtc { get; set; }

    public Lesson Lesson { get; set; } = null!;
    public ICollection<QuizQuestion> Questions { get; set; } = [];
    public ICollection<QuizAttempt> Attempts { get; set; } = [];
}
