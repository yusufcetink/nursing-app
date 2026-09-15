namespace AsliApp.Api.Notifications;

public sealed class PushNotificationOptions
{
    public const string SectionName = "PushNotifications";

    public bool Enabled { get; init; }
    public string? FirebaseCredentialJson { get; init; }
    public string? FirebaseCredentialPath { get; init; }
}
