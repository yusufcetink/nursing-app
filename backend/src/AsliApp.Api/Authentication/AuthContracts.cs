using System.ComponentModel.DataAnnotations;
using AsliApp.Domain.Users;

namespace AsliApp.Api.Authentication;

public sealed record RegisterRequest(
    [Required, MaxLength(100)] string FirstName,
    [Required, MaxLength(100)] string LastName,
    [Required, EmailAddress, MaxLength(256)] string Email,
    [Required, MinLength(8), MaxLength(128)] string Password);

public sealed record LoginRequest(
    [Required, EmailAddress, MaxLength(256)] string Email,
    [Required, MaxLength(128)] string Password);

public sealed record EmailRequest(
    [Required, EmailAddress, MaxLength(256)] string Email);

public sealed record VerifyEmailRequest(
    [Required, EmailAddress, MaxLength(256)] string Email,
    [Required, RegularExpression("^[0-9]{6}$")] string Code);

public sealed record ResetPasswordRequest(
    [Required, EmailAddress, MaxLength(256)] string Email,
    [Required, RegularExpression("^[0-9]{6}$")] string Code,
    [Required, MinLength(8), MaxLength(128)] string NewPassword);

public sealed record UserResponse(
    Guid Id,
    string FirstName,
    string LastName,
    string Email,
    IReadOnlyList<UserRole> Roles);

public sealed record LoginResponse(
    string AccessToken,
    DateTimeOffset ExpiresAtUtc,
    UserResponse User);

public sealed record AuthErrorResponse(IReadOnlyList<string> Errors);

public sealed record AuthOperationResponse(string Message);

public sealed record AuthResult<T>(T? Value, IReadOnlyList<string> Errors)
    where T : class
{
    public bool Succeeded => Value is not null;

    public static AuthResult<T> Success(T value) => new(value, []);

    public static AuthResult<T> Failure(params string[] errors) => new(null, errors);
}
