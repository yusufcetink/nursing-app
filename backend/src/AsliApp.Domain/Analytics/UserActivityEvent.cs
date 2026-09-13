using AsliApp.Domain.Users;

namespace AsliApp.Domain.Analytics;

public sealed class UserActivityEvent
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid SessionId { get; set; }
    public ActivityEventType EventType { get; set; }
    public string? ScreenName { get; set; }
    public DateTimeOffset OccurredAtUtc { get; set; }
    public int? DurationSeconds { get; set; }
    public Guid? ModuleId { get; set; }
    public Guid? LessonId { get; set; }
    public Guid? QuizId { get; set; }
    public Guid? QuestionId { get; set; }
    public string? Target { get; set; }
    public string? MetadataJson { get; set; }
    public Guid ClientEventId { get; set; }

    public User User { get; set; } = null!;
    public AppSession Session { get; set; } = null!;
}
