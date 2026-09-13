namespace AsliApp.Api.Notifications;

public sealed class PushNotificationOptions
{
    public const string SectionName = "PushNotifications";

    public bool Enabled { get; init; }
    public string? FirebaseCredentialJson { get; init; }
    public string? FirebaseCredentialPath { get; init; }
}

public sealed class InactivityReminderOptions
{
    public const string SectionName = "InactivityReminder";

    public int AfterHours { get; init; } = 24;
    public int CooldownHours { get; init; } = 48;
    public int? DevelopmentAfterMinutes { get; init; }
    public int? DevelopmentCooldownMinutes { get; init; }
    public int CheckIntervalMinutes { get; init; } = 60;
}
