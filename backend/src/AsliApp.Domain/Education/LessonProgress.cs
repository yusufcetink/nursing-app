using AsliApp.Domain.Users;

namespace AsliApp.Domain.Education;

public sealed class LessonProgress
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid LessonId { get; set; }
    public bool IsCompleted { get; set; }
    public DateTimeOffset? CompletedAtUtc { get; set; }

    public User User { get; set; } = null!;
    public Lesson Lesson { get; set; } = null!;
}
