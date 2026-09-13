using AsliApp.Domain.Notifications;
using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AsliApp.Api.Notifications;

public sealed class DeviceRegistrationService(AppDbContext dbContext, TimeProvider timeProvider)
{
    public async Task<DeviceRegistrationResponse> RegisterAsync(
        Guid userId,
        RegisterDeviceRequest request,
        CancellationToken cancellationToken)
    {
        var installationId = request.InstallationId.Trim();
        var deviceToken = request.DeviceToken.Trim();
        var matches = await dbContext.UserDevices
            .Where(item => item.InstallationId == installationId || item.DeviceToken == deviceToken)
            .ToListAsync(cancellationToken);
        var installationDevice = matches.SingleOrDefault(item => item.InstallationId == installationId);
        var tokenDevice = matches.SingleOrDefault(item => item.DeviceToken == deviceToken);
        var device = installationDevice ?? tokenDevice;
        var now = timeProvider.GetUtcNow();
        if (device is null)
        {
            device = new UserDevice
            {
                Id = Guid.NewGuid(),
                InstallationId = installationId,
                RegisteredAtUtc = now,
            };
            dbContext.UserDevices.Add(device);
        }

        if (installationDevice is not null && tokenDevice is not null && tokenDevice != installationDevice)
        {
            tokenDevice.DeviceToken = string.Empty;
            tokenDevice.IsActive = false;
            tokenDevice.NotificationsEnabled = false;
            tokenDevice.LastUpdatedAtUtc = now;
        }

        device.UserId = userId;
        device.InstallationId = installationId;
        device.DeviceToken = deviceToken;
        device.Platform = request.Platform.ToLowerInvariant();
        device.NotificationsEnabled = request.NotificationsEnabled;
        device.IsActive = request.NotificationsEnabled;
        device.LastUpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        return new(device.Id, device.IsActive);
    }

    public async Task DeactivateAsync(
        Guid userId,
        string installationId,
        CancellationToken cancellationToken)
    {
        var device = await dbContext.UserDevices.SingleOrDefaultAsync(
            item => item.UserId == userId && item.InstallationId == installationId.Trim(),
            cancellationToken);
        if (device is null) return;
        device.IsActive = false;
        device.NotificationsEnabled = false;
        device.DeviceToken = string.Empty;
        device.LastUpdatedAtUtc = timeProvider.GetUtcNow();
        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
