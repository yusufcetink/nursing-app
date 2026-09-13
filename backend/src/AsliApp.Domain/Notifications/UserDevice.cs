using AsliApp.Domain.Users;

namespace AsliApp.Domain.Notifications;

public sealed class UserDevice
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string InstallationId { get; set; } = string.Empty;
    public string DeviceToken { get; set; } = string.Empty;
    public string Platform { get; set; } = string.Empty;
    public bool NotificationsEnabled { get; set; }
    public bool IsActive { get; set; }
    public DateTimeOffset RegisteredAtUtc { get; set; }
    public DateTimeOffset LastUpdatedAtUtc { get; set; }

    public User User { get; set; } = null!;
}
