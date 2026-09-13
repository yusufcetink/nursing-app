using AsliApp.Domain.Users;

namespace AsliApp.Domain.Notifications;

public sealed class PushNotificationLog
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string NotificationType { get; set; } = string.Empty;
    public DateTimeOffset SentAtUtc { get; set; }
    public DateTimeOffset? OpenedAtUtc { get; set; }
    public bool WasDispatched { get; set; }

    public User User { get; set; } = null!;
}
