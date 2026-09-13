using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Options;

namespace AsliApp.Api.Notifications;

public sealed class FirebasePushNotificationSender : IPushNotificationSender
{
    private readonly PushNotificationOptions _options;
    private readonly Lazy<FirebaseApp> _app;

    public FirebasePushNotificationSender(IOptions<PushNotificationOptions> options)
    {
        _options = options.Value;
        _app = new Lazy<FirebaseApp>(CreateApp, LazyThreadSafetyMode.ExecutionAndPublication);
    }

    public async Task<bool> SendAsync(
        IReadOnlyCollection<string> deviceTokens,
        PushMessage message,
        CancellationToken cancellationToken = default)
    {
        if (!_options.Enabled || deviceTokens.Count == 0) return false;
        var messages = deviceTokens.Distinct().Select(token => new Message
        {
            Fid = token,
            Notification = new Notification { Title = message.Title, Body = message.Body },
            Data = new Dictionary<string, string>(message.Data),
        });
        var response = await FirebaseMessaging.GetMessaging(_app.Value)
            .SendEachAsync(messages, cancellationToken);
        return response.SuccessCount > 0;
    }

    private FirebaseApp CreateApp()
    {
        GoogleCredential credential;
        if (!string.IsNullOrWhiteSpace(_options.FirebaseCredentialJson))
        {
            credential = CredentialFactory
                .FromJson<ServiceAccountCredential>(_options.FirebaseCredentialJson)
                .ToGoogleCredential();
        }
        else if (!string.IsNullOrWhiteSpace(_options.FirebaseCredentialPath))
        {
            credential = CredentialFactory
                .FromFile<ServiceAccountCredential>(_options.FirebaseCredentialPath)
                .ToGoogleCredential();
        }
        else
        {
            credential = GoogleCredential.GetApplicationDefault();
        }

        return FirebaseApp.Create(new AppOptions { Credential = credential }, $"asli-{Guid.NewGuid():N}");
    }
}
