using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace AsliApp.Api.Email;

public sealed class GmailSmtpEmailSender(IOptions<GmailSmtpOptions> options) : IEmailSender
{
    private const string Host = "smtp.gmail.com";
    private const int Port = 587;
    private readonly GmailSmtpOptions _options = options.Value;

    public async Task SendAsync(
        EmailMessage message,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.Address) ||
            string.IsNullOrWhiteSpace(_options.AppPassword))
        {
            throw new InvalidOperationException(
                "Gmail SMTP credentials are not configured.");
        }

        var bodyBuilder = new BodyBuilder { TextBody = message.Body };
        if (!string.IsNullOrWhiteSpace(message.HtmlBody))
        {
            bodyBuilder.HtmlBody = message.HtmlBody;
        }

        var email = new MimeMessage
        {
            Subject = message.Subject,
            Body = bodyBuilder.ToMessageBody(),
        };
        email.From.Add(new MailboxAddress("Aslı App", _options.Address));
        email.To.Add(MailboxAddress.Parse(message.Recipient));

        using var client = new SmtpClient();
        await client.ConnectAsync(
            Host,
            Port,
            SecureSocketOptions.StartTls,
            cancellationToken);
        await client.AuthenticateAsync(
            _options.Address,
            _options.AppPassword,
            cancellationToken);
        await client.SendAsync(email, cancellationToken);
        await client.DisconnectAsync(true, cancellationToken);
    }
}
