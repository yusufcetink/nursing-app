namespace AsliApp.Api.Email;

public interface IEmailSender
{
    Task SendAsync(EmailMessage message, CancellationToken cancellationToken = default);
}

public sealed record EmailMessage(
    string Recipient,
    string Subject,
    string Body,
    string? HtmlBody = null);
