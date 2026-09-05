using AsliApp.Domain.Education;
using Microsoft.AspNetCore.Identity;

namespace AsliApp.Domain.Users;

public sealed class User : IdentityUser<Guid>
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public DateTimeOffset CreatedAtUtc { get; set; }

    public ICollection<QuizAttempt> QuizAttempts { get; set; } = [];
    public ICollection<LessonProgress> LessonProgress { get; set; } = [];
    public ICollection<EmailVerificationCode> EmailVerificationCodes { get; set; } = [];
}
