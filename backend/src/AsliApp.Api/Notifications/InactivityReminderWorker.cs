using Microsoft.Extensions.Options;

namespace AsliApp.Api.Notifications;

public sealed class InactivityReminderWorker(
    IServiceScopeFactory scopeFactory,
    IOptions<InactivityReminderOptions> options,
    IOptions<PushNotificationOptions> pushOptions,
    ILogger<InactivityReminderWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(Math.Max(1, options.Value.CheckIntervalMinutes)));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (pushOptions.Value.Enabled)
                {
                    using var scope = scopeFactory.CreateScope();
                    await scope.ServiceProvider.GetRequiredService<InactivityReminderService>()
                        .SendDueAsync(stoppingToken);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception error)
            {
                logger.LogError(error, "Inactivity reminder run failed.");
            }

            if (!await timer.WaitForNextTickAsync(stoppingToken)) break;
        }
    }
}
