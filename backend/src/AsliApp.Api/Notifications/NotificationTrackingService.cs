using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AsliApp.Api.Notifications;

public sealed class NotificationTrackingService(AppDbContext dbContext, TimeProvider timeProvider)
{
    public async Task MarkOpenedAsync(Guid notificationId, Guid userId, CancellationToken cancellationToken)
    {
        var log = await dbContext.PushNotificationLogs.SingleOrDefaultAsync(
            item => item.Id == notificationId && item.UserId == userId && item.WasDispatched,
            cancellationToken);
        if (log is null || log.OpenedAtUtc is not null) return;
        log.OpenedAtUtc = timeProvider.GetUtcNow();
        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
