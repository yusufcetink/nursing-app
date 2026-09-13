using System.ComponentModel.DataAnnotations;

namespace AsliApp.Api.Notifications;

public sealed record RegisterDeviceRequest(
    [Required, MaxLength(200), RegularExpression(@".*\S.*")] string InstallationId,
    [Required, MaxLength(2048), RegularExpression(@".*\S.*")] string DeviceToken,
    [Required, RegularExpression("^(android|ios)$")] string Platform,
    bool NotificationsEnabled);

public sealed record DeactivateDeviceRequest(
    [Required, MaxLength(200), RegularExpression(@".*\S.*")] string InstallationId);

public sealed record DeviceRegistrationResponse(Guid Id, bool IsActive);
