using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using AsliApp.Api.Email;
using AsliApp.Domain.Users;
using AsliApp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace AsliApp.Api.Authentication;

public sealed class AuthService(
    UserManager<User> userManager,
    AppDbContext dbContext,
    IPasswordHasher<EmailVerificationCode> verificationCodeHasher,
    TimeProvider timeProvider,
    IOptions<JwtOptions> jwtOptions,
    IEmailSender emailSender,
    ILogger<AuthService> logger)
{
    private const int VerificationCodeLifetimeMinutes = 10;
    private const int VerificationCodeMaxFailedAttempts = 5;
    private const int VerificationCodeResendCooldownSeconds = 60;
    private readonly JwtOptions _jwtOptions = jwtOptions.Value;

    public async Task<AuthResult<UserResponse>> RegisterAsync(
        RegisterRequest request,
        CancellationToken cancellationToken = default)
    {
        var email = request.Email.Trim();
        if (await userManager.FindByEmailAsync(email) is not null)
        {
            return AuthResult<UserResponse>.Failure("An account with this email already exists.");
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            FirstName = request.FirstName.Trim(),
            LastName = request.LastName.Trim(),
            Email = email,
            UserName = email,
            CreatedAtUtc = DateTimeOffset.UtcNow,
        };

        var createResult = await userManager.CreateAsync(user, request.Password);
        if (!createResult.Succeeded)
        {
            return AuthResult<UserResponse>.Failure(
                createResult.Errors.Select(error => error.Description).ToArray());
        }

        var role = UserRole.Student;
        var roleResult = await userManager.AddToRoleAsync(user, role.ToString());
        if (!roleResult.Succeeded)
        {
            await userManager.DeleteAsync(user);
            return AuthResult<UserResponse>.Failure("Registration could not be completed.");
        }

        try
        {
            await SendVerificationEmailAsync(user, cancellationToken);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogError(exception, "Verification email could not be sent during registration.");
            await userManager.DeleteAsync(user);
            return AuthResult<UserResponse>.Failure("Verification email could not be sent.");
        }

        return AuthResult<UserResponse>.Success(ToResponse(user, [role]));
    }

    public async Task<AuthResult<LoginResponse>> LoginAsync(
        LoginRequest request,
        CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByEmailAsync(request.Email.Trim());
        if (user is null || !await userManager.CheckPasswordAsync(user, request.Password))
        {
            return AuthResult<LoginResponse>.Failure("Invalid email or password.");
        }

        if (!await userManager.IsEmailConfirmedAsync(user))
        {
            return AuthResult<LoginResponse>.Failure("Email address is not verified.");
        }

        var identityRoles = await userManager.GetRolesAsync(user);
        var roles = ParseRoles(identityRoles);
        if (identityRoles.Count != 1 || roles.Length != 1)
        {
            logger.LogError(
                "Authentication was rejected because an account does not have exactly one application role.");
            return AuthResult<LoginResponse>.Failure("Account authorization is invalid.");
        }
        var expiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(_jwtOptions.ExpirationMinutes);
        var token = CreateToken(user, identityRoles, expiresAtUtc);

        return AuthResult<LoginResponse>.Success(
            new LoginResponse(token, expiresAtUtc, ToResponse(user, roles)));
    }

    public async Task<AuthResult<AuthOperationResponse>> VerifyEmailAsync(
        VerifyEmailRequest request,
        CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByEmailAsync(request.Email.Trim());
        if (user is null)
        {
            return AuthResult<AuthOperationResponse>.Failure(
                "Email verification request is invalid.");
        }

        var purpose = EmailVerificationPurpose.EmailConfirmation;
        var verificationCode = await dbContext.EmailVerificationCodes
            .Where(code => code.UserId == user.Id &&
                code.Purpose == purpose &&
                !code.IsUsed)
            .OrderByDescending(code => code.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        var now = timeProvider.GetUtcNow();
        if (verificationCode is null ||
            verificationCode.ExpiresAtUtc <= now ||
            verificationCode.FailedAttempts >= VerificationCodeMaxFailedAttempts)
        {
            if (verificationCode is not null)
            {
                MarkCodeUsed(verificationCode, now);
                try
                {
                    await dbContext.SaveChangesAsync(cancellationToken);
                }
                catch (DbUpdateConcurrencyException)
                {
                    // Another request already consumed or changed this code.
                }
            }

            return AuthResult<AuthOperationResponse>.Failure(
                "Email verification request is invalid or expired.");
        }

        var verificationResult = verificationCodeHasher.VerifyHashedPassword(
            verificationCode,
            verificationCode.CodeHash,
            request.Code);
        if (verificationResult == PasswordVerificationResult.Failed)
        {
            verificationCode.FailedAttempts++;
            if (verificationCode.FailedAttempts >= VerificationCodeMaxFailedAttempts)
            {
                MarkCodeUsed(verificationCode, now);
            }

            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateConcurrencyException)
            {
                // Concurrent attempts still receive the same non-sensitive response.
            }
            return AuthResult<AuthOperationResponse>.Failure(
                "Email verification request is invalid or expired.");
        }

        MarkCodeUsed(verificationCode, now);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            return AuthResult<AuthOperationResponse>.Failure(
                "Email verification request is invalid or expired.");
        }

        // The Identity token remains internal; users only ever receive the short code.
        var identityToken = await userManager.GenerateEmailConfirmationTokenAsync(user);
        var result = await userManager.ConfirmEmailAsync(user, identityToken);
        if (!result.Succeeded)
        {
            return AuthResult<AuthOperationResponse>.Failure(
                "Email verification request is invalid or expired.");
        }

        return AuthResult<AuthOperationResponse>.Success(
            new AuthOperationResponse("Email address verified."));
    }

    public async Task<AuthResult<AuthOperationResponse>> ResendVerificationAsync(
        EmailRequest request,
        CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByEmailAsync(request.Email.Trim());
        if (user is not null && !await userManager.IsEmailConfirmedAsync(user))
        {
            try
            {
                var latestCode = await dbContext.EmailVerificationCodes
                    .Where(code => code.UserId == user.Id &&
                        code.Purpose == EmailVerificationPurpose.EmailConfirmation)
                    .OrderByDescending(code => code.CreatedAtUtc)
                    .FirstOrDefaultAsync(cancellationToken);
                var now = timeProvider.GetUtcNow();
                if (latestCode is not null)
                {
                    var nextSendAt = latestCode.CreatedAtUtc.AddSeconds(
                        VerificationCodeResendCooldownSeconds);
                    if (nextSendAt > now)
                    {
                        return AuthResult<AuthOperationResponse>.Success(
                            new AuthOperationResponse(
                                "Please wait before requesting another verification email."));
                    }
                }

                await SendVerificationEmailAsync(user, cancellationToken);
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                logger.LogError(exception, "Verification email could not be resent.");
            }
        }

        return AuthResult<AuthOperationResponse>.Success(
            new AuthOperationResponse(
                "If the account is eligible, a verification email has been sent."));
    }

    public async Task<AuthResult<AuthOperationResponse>> ForgotPasswordAsync(
        EmailRequest request,
        CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByEmailAsync(request.Email.Trim());
        if (user is not null && await userManager.IsEmailConfirmedAsync(user))
        {
            try
            {
                var purpose = EmailVerificationPurpose.PasswordReset;
                var latestCode = await dbContext.EmailVerificationCodes
                    .Where(code => code.UserId == user.Id && code.Purpose == purpose)
                    .OrderByDescending(code => code.CreatedAtUtc)
                    .FirstOrDefaultAsync(cancellationToken);
                var now = timeProvider.GetUtcNow();
                if (latestCode is not null &&
                    latestCode.CreatedAtUtc.AddSeconds(
                        VerificationCodeResendCooldownSeconds) > now)
                {
                    return AuthResult<AuthOperationResponse>.Success(
                        new AuthOperationResponse(
                            "If an eligible account exists, a password reset email has been sent."));
                }

                await SendPasswordResetCodeAsync(user, cancellationToken);
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                logger.LogError(exception, "Password reset email could not be sent.");
            }
        }

        return AuthResult<AuthOperationResponse>.Success(
            new AuthOperationResponse(
                "If an eligible account exists, a password reset email has been sent."));
    }

    public async Task<AuthResult<AuthOperationResponse>> ResetPasswordAsync(
        ResetPasswordRequest request,
        CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByEmailAsync(request.Email.Trim());
        if (user is null)
        {
            return AuthResult<AuthOperationResponse>.Failure(
                "Password reset request is invalid or expired.");
        }

        var purpose = EmailVerificationPurpose.PasswordReset;
        var resetCode = await dbContext.EmailVerificationCodes
            .Where(code => code.UserId == user.Id &&
                code.Purpose == purpose &&
                !code.IsUsed)
            .OrderByDescending(code => code.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        var now = timeProvider.GetUtcNow();
        if (resetCode is null ||
            resetCode.ExpiresAtUtc <= now ||
            resetCode.FailedAttempts >= VerificationCodeMaxFailedAttempts)
        {
            if (resetCode is not null)
            {
                MarkCodeUsed(resetCode, now);
                try
                {
                    await dbContext.SaveChangesAsync(cancellationToken);
                }
                catch (DbUpdateConcurrencyException)
                {
                    // Another request already consumed or changed this code.
                }
            }
            return AuthResult<AuthOperationResponse>.Failure(
                "Password reset request is invalid or expired.");
        }

        var verificationResult = verificationCodeHasher.VerifyHashedPassword(
            resetCode,
            resetCode.CodeHash,
            request.Code);
        if (verificationResult == PasswordVerificationResult.Failed)
        {
            resetCode.FailedAttempts++;
            if (resetCode.FailedAttempts >= VerificationCodeMaxFailedAttempts)
            {
                MarkCodeUsed(resetCode, now);
            }
            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateConcurrencyException)
            {
                // Concurrent attempts receive the same non-sensitive response.
            }
            return AuthResult<AuthOperationResponse>.Failure(
                "Password reset request is invalid or expired.");
        }

        MarkCodeUsed(resetCode, now);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            return AuthResult<AuthOperationResponse>.Failure(
                "Password reset request is invalid or expired.");
        }

        var identityToken = await userManager.GeneratePasswordResetTokenAsync(user);
        var result = await userManager.ResetPasswordAsync(
            user,
            identityToken,
            request.NewPassword);
        if (!result.Succeeded)
        {
            return AuthResult<AuthOperationResponse>.Failure(
                result.Errors.Select(error => error.Description).ToArray());
        }

        return AuthResult<AuthOperationResponse>.Success(
            new AuthOperationResponse("Password has been reset."));
    }

    public async Task<AuthResult<UserResponse>> GetUserAsync(Guid userId)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return AuthResult<UserResponse>.Failure("Authenticated user was not found.");
        }

        var identityRoles = await userManager.GetRolesAsync(user);
        return AuthResult<UserResponse>.Success(
            ToResponse(user, ParseRoles(identityRoles)));
    }

    private async Task SendVerificationEmailAsync(
        User user,
        CancellationToken cancellationToken)
    {
        var now = timeProvider.GetUtcNow();
        var purpose = EmailVerificationPurpose.EmailConfirmation;
        var activeCodes = await dbContext.EmailVerificationCodes
            .Where(code => code.UserId == user.Id &&
                code.Purpose == purpose &&
                !code.IsUsed)
            .ToListAsync(cancellationToken);
        foreach (var activeCode in activeCodes)
        {
            MarkCodeUsed(activeCode, now);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        var plainCode = RandomNumberGenerator.GetInt32(1_000_000).ToString("D6");
        var verificationCode = new EmailVerificationCode
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Purpose = purpose,
            CreatedAtUtc = now,
            ExpiresAtUtc = now.AddMinutes(VerificationCodeLifetimeMinutes),
        };
        verificationCode.CodeHash = verificationCodeHasher.HashPassword(
            verificationCode,
            plainCode);
        dbContext.EmailVerificationCodes.Add(verificationCode);
        await dbContext.SaveChangesAsync(cancellationToken);

        var encodedName = WebUtility.HtmlEncode(user.FirstName);
        var htmlBody = $$"""
            <!doctype html>
            <html lang="tr">
              <body style="margin:0;background:#f4f6f8;font-family:Arial,sans-serif;color:#1f2937">
                <div style="max-width:560px;margin:32px auto;padding:32px;background:#ffffff;border-radius:16px">
                  <h1 style="margin:0 0 16px;font-size:24px;color:#5b3cc4">Aslı App</h1>
                  <p>Merhaba {{encodedName}},</p>
                  <p>Email adresinizi doğrulamak için aşağıdaki kodu uygulamaya girin:</p>
                  <div style="margin:28px 0;padding:18px;text-align:center;background:#f3f0ff;border-radius:12px;font-size:36px;font-weight:700;letter-spacing:10px;color:#3f2a8a">{{plainCode}}</div>
                  <p style="font-size:14px;color:#6b7280">Bu kod 10 dakika geçerlidir ve yalnızca bir kez kullanılabilir.</p>
                  <p style="font-size:14px;color:#6b7280">Bu hesabı siz oluşturmadıysanız bu emaili dikkate almayın.</p>
                </div>
              </body>
            </html>
            """;

        try
        {
            await emailSender.SendAsync(
                new EmailMessage(
                    user.Email!,
                    "Aslı App email doğrulama kodunuz",
                    $"Merhaba {user.FirstName},\n\nEmail doğrulama kodunuz: {plainCode}\n\n" +
                    "Bu kod 10 dakika geçerlidir ve yalnızca bir kez kullanılabilir.\n\n" +
                    "Bu hesabı siz oluşturmadıysanız bu emaili dikkate almayın.",
                    htmlBody),
                cancellationToken);
        }
        catch
        {
            MarkCodeUsed(verificationCode, timeProvider.GetUtcNow());
            await dbContext.SaveChangesAsync(CancellationToken.None);
            throw;
        }
    }

    private async Task SendPasswordResetCodeAsync(
        User user,
        CancellationToken cancellationToken)
    {
        var now = timeProvider.GetUtcNow();
        var purpose = EmailVerificationPurpose.PasswordReset;
        var activeCodes = await dbContext.EmailVerificationCodes
            .Where(code => code.UserId == user.Id &&
                code.Purpose == purpose &&
                !code.IsUsed)
            .ToListAsync(cancellationToken);
        foreach (var activeCode in activeCodes)
        {
            MarkCodeUsed(activeCode, now);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        var plainCode = RandomNumberGenerator.GetInt32(1_000_000).ToString("D6");
        var resetCode = new EmailVerificationCode
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Purpose = purpose,
            CreatedAtUtc = now,
            ExpiresAtUtc = now.AddMinutes(VerificationCodeLifetimeMinutes),
        };
        resetCode.CodeHash = verificationCodeHasher.HashPassword(resetCode, plainCode);
        dbContext.EmailVerificationCodes.Add(resetCode);
        await dbContext.SaveChangesAsync(cancellationToken);

        var encodedName = WebUtility.HtmlEncode(user.FirstName);
        var htmlBody = $$"""
            <!doctype html>
            <html lang="tr">
              <body style="margin:0;background:#f4f6f8;font-family:Arial,sans-serif;color:#1f2937">
                <div style="max-width:560px;margin:32px auto;padding:32px;background:#ffffff;border-radius:16px">
                  <h1 style="margin:0 0 16px;font-size:24px;color:#5b3cc4">Aslı App</h1>
                  <p>Merhaba {{encodedName}},</p>
                  <p>Şifrenizi sıfırlamak için aşağıdaki kodu uygulamaya girin:</p>
                  <div style="margin:28px 0;padding:18px;text-align:center;background:#f3f0ff;border-radius:12px;font-size:36px;font-weight:700;letter-spacing:10px;color:#3f2a8a">{{plainCode}}</div>
                  <p style="font-size:14px;color:#6b7280">Bu kod 10 dakika geçerlidir ve yalnızca bir kez kullanılabilir.</p>
                  <p style="font-size:14px;color:#6b7280">Bu isteği siz yapmadıysanız bu emaili dikkate almayın.</p>
                </div>
              </body>
            </html>
            """;

        try
        {
            await emailSender.SendAsync(
                new EmailMessage(
                    user.Email!,
                    "Aslı App şifre sıfırlama kodunuz",
                    $"Merhaba {user.FirstName},\n\nŞifre sıfırlama kodunuz: {plainCode}\n\n" +
                    "Bu kod 10 dakika geçerlidir ve yalnızca bir kez kullanılabilir.\n\n" +
                    "Bu isteği siz yapmadıysanız bu emaili dikkate almayın.",
                    htmlBody),
                cancellationToken);
        }
        catch
        {
            MarkCodeUsed(resetCode, timeProvider.GetUtcNow());
            await dbContext.SaveChangesAsync(CancellationToken.None);
            throw;
        }
    }

    private static void MarkCodeUsed(EmailVerificationCode code, DateTimeOffset usedAtUtc)
    {
        code.IsUsed = true;
        code.UsedAtUtc = usedAtUtc;
    }

    private string CreateToken(
        User user,
        IEnumerable<string> roles,
        DateTimeOffset expiresAtUtc)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
            new("security_stamp", user.SecurityStamp ?? string.Empty),
        };
        claims.AddRange(roles.Select(role => new Claim("role", role)));

        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtOptions.Key)),
            SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            issuer: _jwtOptions.Issuer,
            audience: _jwtOptions.Audience,
            claims: claims,
            expires: expiresAtUtc.UtcDateTime,
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static UserRole[] ParseRoles(IEnumerable<string> identityRoles) =>
        identityRoles
            .Select(role => Enum.TryParse<UserRole>(role, out var parsedRole)
                ? parsedRole
                : (UserRole?)null)
            .OfType<UserRole>()
            .ToArray();

    private static UserResponse ToResponse(User user, IReadOnlyList<UserRole> roles) =>
        new(
            user.Id,
            user.FirstName,
            user.LastName,
            user.Email ?? string.Empty,
            roles);
}
