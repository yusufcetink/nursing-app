namespace AsliApp.Domain.Users;

public sealed class EmailVerificationCode
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public EmailVerificationPurpose Purpose { get; set; }
    public string CodeHash { get; set; } = string.Empty;
    public DateTimeOffset CreatedAtUtc { get; set; }
    public DateTimeOffset ExpiresAtUtc { get; set; }
    public int FailedAttempts { get; set; }
    public bool IsUsed { get; set; }
    public DateTimeOffset? UsedAtUtc { get; set; }
    public byte[] RowVersion { get; set; } = [];

    public User User { get; set; } = null!;
}

public enum EmailVerificationPurpose
{
    EmailConfirmation = 1,
}
