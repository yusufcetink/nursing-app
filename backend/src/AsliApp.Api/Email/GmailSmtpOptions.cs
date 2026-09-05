namespace AsliApp.Api.Email;

public sealed class GmailSmtpOptions
{
    public const string SectionName = "Gmail";

    public string Address { get; set; } = string.Empty;

    public string AppPassword { get; set; } = string.Empty;
}
