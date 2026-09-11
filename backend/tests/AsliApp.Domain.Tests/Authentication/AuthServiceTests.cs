using System.IdentityModel.Tokens.Jwt;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using AsliApp.Api.Authentication;
using AsliApp.Api.Email;
using AsliApp.Domain.Users;
using Microsoft.AspNetCore.DataProtection;
using AsliApp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace AsliApp.Domain.Tests.Authentication;

public sealed class AuthServiceTests
{
    [Fact]
    public async Task RegisterHashesPasswordAndAssignsStudentRole()
    {
        await using var context = new AuthTestContext();
        var request = new RegisterRequest(
            "Aslı",
            "Yılmaz",
            "asli@example.com",
            "SecurePass1!");

        var result = await context.AuthService.RegisterAsync(request);

        Assert.True(result.Succeeded);
        Assert.NotNull(result.Value);
        Assert.Equal([UserRole.Student], result.Value.Roles);

        var user = await context.UserManager.FindByEmailAsync(request.Email);
        Assert.NotNull(user);
        Assert.NotNull(user.PasswordHash);
        Assert.NotEqual(request.Password, user.PasswordHash);
        Assert.False(user.EmailConfirmed);
        Assert.True(await context.UserManager.CheckPasswordAsync(user, request.Password));
        Assert.True(await context.UserManager.IsInRoleAsync(user, UserRole.Student.ToString()));
        Assert.Single(context.EmailSender.Messages);
        Assert.Contains("Aslı App", context.EmailSender.Messages.Single().Subject);
        Assert.NotNull(context.EmailSender.Messages.Single().HtmlBody);

        var storedCode = await context.DbContext.EmailVerificationCodes.SingleAsync();
        var plainCode = Regex.Match(context.EmailSender.Messages.Single().Body, @"\b\d{6}\b").Value;
        Assert.Matches(@"^\d{6}$", plainCode);
        Assert.DoesNotContain(plainCode, storedCode.CodeHash);
        Assert.NotEqual(plainCode, storedCode.CodeHash);
    }

    [Fact]
    public async Task LoginReturnsJwtWithUserEmailAndRoleClaims()
    {
        await using var context = new AuthTestContext();
        const string email = "student@example.com";
        const string password = "SecurePass1!";
        await context.AuthService.RegisterAsync(
            new RegisterRequest("Student", "User", email, password));
        var user = await context.UserManager.FindByEmailAsync(email);
        Assert.NotNull(user);
        var confirmationToken = await context.UserManager.GenerateEmailConfirmationTokenAsync(user);
        Assert.True((await context.UserManager.ConfirmEmailAsync(user, confirmationToken)).Succeeded);

        var result = await context.AuthService.LoginAsync(new LoginRequest(email, password));

        Assert.True(result.Succeeded);
        Assert.NotNull(result.Value);
        var token = new JwtSecurityTokenHandler().ReadJwtToken(result.Value.AccessToken);
        Assert.Equal(result.Value.User.Id.ToString(), token.Claims.Single(claim => claim.Type == "sub").Value);
        Assert.Equal(email, token.Claims.Single(claim => claim.Type == "email").Value);
        Assert.Equal(
            UserRole.Student.ToString(),
            token.Claims.Single(claim => claim.Type == "role").Value);
    }

    [Fact]
    public async Task LoginRejectsAnUnverifiedEmail()
    {
        await using var context = new AuthTestContext();
        const string email = "unverified@example.com";
        const string password = "SecurePass1!";
        await context.AuthService.RegisterAsync(
            new RegisterRequest("Student", "User", email, password));

        var result = await context.AuthService.LoginAsync(new LoginRequest(email, password));

        Assert.False(result.Succeeded);
        Assert.Equal(["Email address is not verified."], result.Errors);
    }

    [Fact]
    public async Task LoginRejectsAnInvalidPassword()
    {
        await using var context = new AuthTestContext();
        await context.AuthService.RegisterAsync(
            new RegisterRequest("Student", "User", "student@example.com", "SecurePass1!"));

        var result = await context.AuthService.LoginAsync(
            new LoginRequest("student@example.com", "WrongPass1!"));

        Assert.False(result.Succeeded);
        Assert.Null(result.Value);
        Assert.Equal(["Invalid email or password."], result.Errors);
    }

    [Fact]
    public async Task VerificationCodeIsSingleUseAndConfirmsIdentityEmail()
    {
        await using var context = new AuthTestContext();
        const string email = "verify@example.com";
        await context.AuthService.RegisterAsync(
            new RegisterRequest("Verify", "User", email, "SecurePass1!"));
        var code = Regex.Match(context.EmailSender.Messages.Single().Body, @"\b\d{6}\b").Value;

        var result = await context.AuthService.VerifyEmailAsync(
            new VerifyEmailRequest(email, code));
        var reusedResult = await context.AuthService.VerifyEmailAsync(
            new VerifyEmailRequest(email, code));

        Assert.True(result.Succeeded);
        Assert.False(reusedResult.Succeeded);
        var user = await context.UserManager.FindByEmailAsync(email);
        Assert.NotNull(user);
        Assert.True(await context.UserManager.IsEmailConfirmedAsync(user));
        var storedCode = await context.DbContext.EmailVerificationCodes.SingleAsync();
        Assert.True(storedCode.IsUsed);
        Assert.NotNull(storedCode.UsedAtUtc);
    }

    [Fact]
    public async Task VerificationCodeLocksAfterFiveFailedAttempts()
    {
        await using var context = new AuthTestContext();
        const string email = "attempts@example.com";
        await context.AuthService.RegisterAsync(
            new RegisterRequest("Attempts", "User", email, "SecurePass1!"));
        var issuedCode = Regex.Match(context.EmailSender.Messages.Single().Body, @"\b\d{6}\b").Value;
        var wrongCode = issuedCode == "999999" ? "000000" : "999999";

        for (var attempt = 0; attempt < 5; attempt++)
        {
            var result = await context.AuthService.VerifyEmailAsync(
                new VerifyEmailRequest(email, wrongCode));
            Assert.False(result.Succeeded);
        }

        var storedCode = await context.DbContext.EmailVerificationCodes.SingleAsync();
        Assert.Equal(5, storedCode.FailedAttempts);
        Assert.True(storedCode.IsUsed);
    }

    [Fact]
    public async Task VerificationCodeExpiresAfterTenMinutes()
    {
        await using var context = new AuthTestContext();
        const string email = "expired@example.com";
        await context.AuthService.RegisterAsync(
            new RegisterRequest("Expired", "User", email, "SecurePass1!"));
        var code = Regex.Match(context.EmailSender.Messages.Single().Body, @"\b\d{6}\b").Value;
        context.Clock.Advance(TimeSpan.FromMinutes(10));

        var result = await context.AuthService.VerifyEmailAsync(
            new VerifyEmailRequest(email, code));

        Assert.False(result.Succeeded);
        Assert.True((await context.DbContext.EmailVerificationCodes.SingleAsync()).IsUsed);
    }

    [Fact]
    public async Task ResendHonorsCooldownAndInvalidatesPreviousCode()
    {
        await using var context = new AuthTestContext();
        const string email = "resend@example.com";
        await context.AuthService.RegisterAsync(
            new RegisterRequest("Resend", "User", email, "SecurePass1!"));

        await context.AuthService.ResendVerificationAsync(new EmailRequest(email));
        Assert.Single(context.EmailSender.Messages);

        context.Clock.Advance(TimeSpan.FromSeconds(60));
        await context.AuthService.ResendVerificationAsync(new EmailRequest(email));

        Assert.Equal(2, context.EmailSender.Messages.Count);
        var codes = await context.DbContext.EmailVerificationCodes
            .OrderBy(code => code.CreatedAtUtc)
            .ToListAsync();
        Assert.Equal(2, codes.Count);
        Assert.True(codes[0].IsUsed);
        Assert.False(codes[1].IsUsed);
    }

    [Fact]
    public async Task PasswordResetCodeIsHashedSingleUseAndResetsWithInternalIdentityToken()
    {
        await using var context = new AuthTestContext();
        const string email = "password-reset@example.com";
        var user = await CreateConfirmedUserAsync(context, email);

        await context.AuthService.ForgotPasswordAsync(new EmailRequest(email));
        var message = context.EmailSender.Messages.Last(item =>
            item.Subject.Contains("şifre sıfırlama"));
        var code = Regex.Match(message.Body, @"\b\d{6}\b").Value;
        var storedCode = await context.DbContext.EmailVerificationCodes.SingleAsync(item =>
            item.Purpose == EmailVerificationPurpose.PasswordReset);

        Assert.Matches(@"^\d{6}$", code);
        Assert.DoesNotContain(code, storedCode.CodeHash);
        Assert.DoesNotContain("token", message.Body, StringComparison.OrdinalIgnoreCase);

        var result = await context.AuthService.ResetPasswordAsync(
            new ResetPasswordRequest(email, code, "NewSecurePass2!"));
        var reusedResult = await context.AuthService.ResetPasswordAsync(
            new ResetPasswordRequest(email, code, "AnotherPass3!"));

        Assert.True(result.Succeeded);
        Assert.False(reusedResult.Succeeded);
        Assert.True(storedCode.IsUsed);
        Assert.True(await context.UserManager.CheckPasswordAsync(user, "NewSecurePass2!"));
    }

    [Fact]
    public async Task PasswordResetCodeLocksAfterFiveFailedAttempts()
    {
        await using var context = new AuthTestContext();
        const string email = "password-attempts@example.com";
        await CreateConfirmedUserAsync(context, email);
        await context.AuthService.ForgotPasswordAsync(new EmailRequest(email));
        var issuedCode = Regex.Match(
            context.EmailSender.Messages.Last().Body,
            @"\b\d{6}\b").Value;
        var wrongCode = issuedCode == "999999" ? "000000" : "999999";

        for (var attempt = 0; attempt < 5; attempt++)
        {
            var result = await context.AuthService.ResetPasswordAsync(
                new ResetPasswordRequest(email, wrongCode, "NewSecurePass2!"));
            Assert.False(result.Succeeded);
        }

        var storedCode = await context.DbContext.EmailVerificationCodes.SingleAsync(item =>
            item.Purpose == EmailVerificationPurpose.PasswordReset);
        Assert.Equal(5, storedCode.FailedAttempts);
        Assert.True(storedCode.IsUsed);
    }

    [Fact]
    public async Task PasswordResetCodeExpiresAfterTenMinutes()
    {
        await using var context = new AuthTestContext();
        const string email = "password-expired@example.com";
        await CreateConfirmedUserAsync(context, email);
        await context.AuthService.ForgotPasswordAsync(new EmailRequest(email));
        var code = Regex.Match(context.EmailSender.Messages.Last().Body, @"\b\d{6}\b").Value;
        context.Clock.Advance(TimeSpan.FromMinutes(10));

        var result = await context.AuthService.ResetPasswordAsync(
            new ResetPasswordRequest(email, code, "NewSecurePass2!"));

        Assert.False(result.Succeeded);
        Assert.True((await context.DbContext.EmailVerificationCodes.SingleAsync(item =>
            item.Purpose == EmailVerificationPurpose.PasswordReset)).IsUsed);
    }

    [Fact]
    public async Task PasswordResetResendHonorsCooldownAndInvalidatesPreviousCode()
    {
        await using var context = new AuthTestContext();
        const string email = "password-resend@example.com";
        await CreateConfirmedUserAsync(context, email);

        await context.AuthService.ForgotPasswordAsync(new EmailRequest(email));
        var sentMessageCount = context.EmailSender.Messages.Count;
        await context.AuthService.ForgotPasswordAsync(new EmailRequest(email));
        Assert.Equal(sentMessageCount, context.EmailSender.Messages.Count);

        context.Clock.Advance(TimeSpan.FromSeconds(60));
        await context.AuthService.ForgotPasswordAsync(new EmailRequest(email));

        Assert.Equal(sentMessageCount + 1, context.EmailSender.Messages.Count);
        var codes = await context.DbContext.EmailVerificationCodes
            .Where(item => item.Purpose == EmailVerificationPurpose.PasswordReset)
            .OrderBy(item => item.CreatedAtUtc)
            .ToListAsync();
        Assert.Equal(2, codes.Count);
        Assert.True(codes[0].IsUsed);
        Assert.False(codes[1].IsUsed);
    }

    private static async Task<User> CreateConfirmedUserAsync(
        AuthTestContext context,
        string email)
    {
        await context.AuthService.RegisterAsync(
            new RegisterRequest("Password", "Reset", email, "SecurePass1!"));
        var user = await context.UserManager.FindByEmailAsync(email);
        Assert.NotNull(user);
        var token = await context.UserManager.GenerateEmailConfirmationTokenAsync(user);
        Assert.True((await context.UserManager.ConfirmEmailAsync(user, token)).Succeeded);
        return user;
    }

    private sealed class AuthTestContext : IAsyncDisposable
    {
        private readonly ServiceProvider _serviceProvider;
        private readonly AsyncServiceScope _scope;

        public AuthTestContext()
        {
            var services = new ServiceCollection();
            services.AddLogging();
            services.AddDataProtection();
            services.AddDbContext<AppDbContext>(options =>
                options.UseInMemoryDatabase(Guid.NewGuid().ToString()));
            services
                .AddIdentityCore<User>(options =>
                {
                    options.User.RequireUniqueEmail = true;
                    options.Password.RequiredLength = 8;
                })
                .AddRoles<IdentityRole<Guid>>()
                .AddEntityFrameworkStores<AppDbContext>()
                .AddDefaultTokenProviders();
            services.Configure<JwtOptions>(options =>
            {
                options.Issuer = "AsliApp.Tests";
                options.Audience = "AsliApp.Tests.Client";
                options.Key = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));
                options.ExpirationMinutes = 15;
            });
            services.AddSingleton<TestEmailSender>();
            services.AddSingleton<IEmailSender>(provider =>
                provider.GetRequiredService<TestEmailSender>());
            services.AddScoped<IPasswordHasher<EmailVerificationCode>, PasswordHasher<EmailVerificationCode>>();
            services.AddSingleton<TestTimeProvider>();
            services.AddSingleton<TimeProvider>(provider =>
                provider.GetRequiredService<TestTimeProvider>());
            services.AddScoped<AuthService>();

            _serviceProvider = services.BuildServiceProvider();
            _scope = _serviceProvider.CreateAsyncScope();
            _scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.EnsureCreated();
        }

        public AuthService AuthService =>
            _scope.ServiceProvider.GetRequiredService<AuthService>();

        public UserManager<User> UserManager =>
            _scope.ServiceProvider.GetRequiredService<UserManager<User>>();

        public AppDbContext DbContext =>
            _scope.ServiceProvider.GetRequiredService<AppDbContext>();

        public TestTimeProvider Clock =>
            _scope.ServiceProvider.GetRequiredService<TestTimeProvider>();

        public TestEmailSender EmailSender =>
            _scope.ServiceProvider.GetRequiredService<TestEmailSender>();

        public async ValueTask DisposeAsync()
        {
            await _scope.DisposeAsync();
            await _serviceProvider.DisposeAsync();
        }
    }

    private sealed class TestTimeProvider : TimeProvider
    {
        private DateTimeOffset _utcNow = new(2026, 9, 5, 12, 0, 0, TimeSpan.Zero);

        public override DateTimeOffset GetUtcNow() => _utcNow;

        public void Advance(TimeSpan duration) => _utcNow += duration;
    }

    private sealed class TestEmailSender : IEmailSender
    {
        public List<EmailMessage> Messages { get; } = [];

        public Task SendAsync(
            EmailMessage message,
            CancellationToken cancellationToken = default)
        {
            Messages.Add(message);
            return Task.CompletedTask;
        }
    }
}
