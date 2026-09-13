using AsliApp.Domain.Users;

namespace AsliApp.Domain.Analytics;

public sealed class AppSession
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public DateTimeOffset StartedAtUtc { get; set; }
    public DateTimeOffset LastActivityAtUtc { get; set; }
    public DateTimeOffset? EndedAtUtc { get; set; }
    public int ActiveDurationSeconds { get; set; }

    public User User { get; set; } = null!;
    public ICollection<UserActivityEvent> Events { get; set; } = [];
}
