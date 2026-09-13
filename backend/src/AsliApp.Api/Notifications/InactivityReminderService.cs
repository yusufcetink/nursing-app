using AsliApp.Domain.Analytics;
using AsliApp.Domain.Notifications;
using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace AsliApp.Api.Notifications;

public sealed class InactivityReminderService(
    AppDbContext dbContext,
    IPushNotificationSender sender,
    IOptions<InactivityReminderOptions> options,
    IHostEnvironment environment,
    TimeProvider timeProvider)
{
    public const string NotificationType = "inactivity_reminder";

    public async Task<int> SendDueAsync(CancellationToken cancellationToken)
    {
        var now = timeProvider.GetUtcNow();
        var inactiveBefore = now - ResolveAfter(options.Value, environment.IsDevelopment());
        var cooldownAfter = now - ResolveCooldown(options.Value, environment.IsDevelopment());
        var candidates = await dbContext.Users
            .Where(user =>
                user.AppSessions.Any() &&
                user.AppSessions.Max(session => session.LastActivityAtUtc) <= inactiveBefore &&
                user.Devices.Any(device => device.IsActive && device.NotificationsEnabled && device.DeviceToken != "") &&
                !user.NotificationLogs.Any(log => log.NotificationType == NotificationType && log.WasDispatched && log.SentAtUtc > cooldownAfter))
            .Select(user => new
            {
                user.Id,
                SessionId = user.AppSessions
                    .OrderByDescending(session => session.LastActivityAtUtc)
                    .Select(session => session.Id)
                    .First(),
                Tokens = user.Devices
                    .Where(device => device.IsActive && device.NotificationsEnabled && device.DeviceToken != "")
                    .Select(device => device.DeviceToken)
                    .ToArray(),
            })
            .ToListAsync(cancellationToken);

        var sent = 0;
        foreach (var candidate in candidates)
        {
            var notificationId = Guid.NewGuid();
            var dispatched = await sender.SendAsync(
                candidate.Tokens,
                new PushMessage(
                    "Aslı App seni bekliyor 👋",
                    "Kısa bir dersle kaldığın yerden devam etmeye ne dersin?",
                    new Dictionary<string, string>
                    {
                        ["route"] = "/home",
                        ["type"] = NotificationType,
                        ["notificationId"] = notificationId.ToString(),
                    }),
                cancellationToken);
            dbContext.PushNotificationLogs.Add(new PushNotificationLog
            {
                Id = notificationId,
                UserId = candidate.Id,
                NotificationType = NotificationType,
                SentAtUtc = now,
                WasDispatched = dispatched,
            });
            if (dispatched)
            {
                dbContext.UserActivityEvents.Add(new UserActivityEvent
                {
                    Id = Guid.NewGuid(),
                    ClientEventId = notificationId,
                    UserId = candidate.Id,
                    SessionId = candidate.SessionId,
                    EventType = ActivityEventType.NotificationSent,
                    OccurredAtUtc = now,
                    Target = NotificationType,
                });
                sent++;
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return sent;
    }

    internal static TimeSpan ResolveAfter(InactivityReminderOptions value, bool isDevelopment) =>
        isDevelopment && value.DevelopmentAfterMinutes is > 0
            ? TimeSpan.FromMinutes(value.DevelopmentAfterMinutes.Value)
            : TimeSpan.FromHours(Math.Max(1, value.AfterHours));

    internal static TimeSpan ResolveCooldown(InactivityReminderOptions value, bool isDevelopment) =>
        isDevelopment && value.DevelopmentCooldownMinutes is > 0
            ? TimeSpan.FromMinutes(value.DevelopmentCooldownMinutes.Value)
            : TimeSpan.FromHours(Math.Max(1, value.CooldownHours));
}
