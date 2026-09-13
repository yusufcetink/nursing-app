namespace AsliApp.Api.Notifications;

public sealed record PushMessage(
    string Title,
    string Body,
    IReadOnlyDictionary<string, string> Data);

public interface IPushNotificationSender
{
    Task<bool> SendAsync(
        IReadOnlyCollection<string> deviceTokens,
        PushMessage message,
        CancellationToken cancellationToken = default);
}
