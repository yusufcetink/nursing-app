using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using AsliApp.Api.Authentication;
using AsliApp.Api.Email;
using AsliApp.Domain.Users;
using AsliApp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.IdentityModel.Tokens;

namespace AsliApp.Domain.Tests.Authentication;

public sealed class AuthEndpointsTests : IClassFixture<AuthApiFactory>
{
    private static readonly JsonSerializerOptions JsonOptions = CreateJsonOptions();
    private readonly HttpClient _client;
    private readonly AuthApiFactory _factory;

    public AuthEndpointsTests(AuthApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task RegisterThenLoginReturnsExpectedJwtClaims()
    {
        const string email = "endpoint.test@example.com";
        const string password = "SecurePass1!";
        var registerResponse = await _client.PostAsJsonAsync(
            "/api/auth/register",
            new RegisterRequest("Endpoint", "Test", email, password));

        Assert.Equal(HttpStatusCode.Created, registerResponse.StatusCode);
        var registeredUser = await registerResponse.Content.ReadFromJsonAsync<UserResponse>(JsonOptions);
        Assert.NotNull(registeredUser);

        var unverifiedLoginResponse = await _client.PostAsJsonAsync(
            "/api/auth/login",
            new LoginRequest(email, password));
        Assert.Equal(HttpStatusCode.Unauthorized, unverifiedLoginResponse.StatusCode);

        var resendResponse = await _client.PostAsJsonAsync(
            "/api/auth/resend-verification",
            new EmailRequest(email));
        Assert.Equal(HttpStatusCode.OK, resendResponse.StatusCode);

        string verificationCode;
        using (var scope = _factory.Services.CreateScope())
        {
            var emailSender = Assert.IsType<EndpointEmailSender>(
                scope.ServiceProvider.GetRequiredService<IEmailSender>());
            var message = emailSender.Messages.Last(message => message.Recipient == email);
            verificationCode = Regex.Match(message.Body, @"\b\d{6}\b").Value;
            Assert.Matches(@"^\d{6}$", verificationCode);
            Assert.DoesNotContain("token", message.Body, StringComparison.OrdinalIgnoreCase);
        }

        var verifyResponse = await _client.PostAsJsonAsync(
            "/api/auth/verify-email",
            new VerifyEmailRequest(email, verificationCode));
        Assert.Equal(HttpStatusCode.OK, verifyResponse.StatusCode);

        var loginResponse = await _client.PostAsJsonAsync(
            "/api/auth/login",
            new LoginRequest(email, password));

        Assert.Equal(HttpStatusCode.OK, loginResponse.StatusCode);
        var login = await loginResponse.Content.ReadFromJsonAsync<LoginResponse>(JsonOptions);
        Assert.NotNull(login);
        var token = new JwtSecurityTokenHandler().ReadJwtToken(login.AccessToken);
        Assert.Equal(registeredUser.Id.ToString(), token.Claims.Single(claim => claim.Type == "sub").Value);
        Assert.Equal(email, token.Claims.Single(claim => claim.Type == "email").Value);
        Assert.Equal("Student", token.Claims.Single(claim => claim.Type == "role").Value);

        using var meRequest = new HttpRequestMessage(HttpMethod.Get, "/api/auth/me");
        meRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", login.AccessToken);
        var meResponse = await _client.SendAsync(meRequest);

        Assert.Equal(HttpStatusCode.OK, meResponse.StatusCode);
        var currentUser = await meResponse.Content.ReadFromJsonAsync<UserResponse>(JsonOptions);
        Assert.NotNull(currentUser);
        Assert.Equal(registeredUser.Id, currentUser.Id);
        Assert.Equal(registeredUser.FirstName, currentUser.FirstName);
        Assert.Equal(registeredUser.LastName, currentUser.LastName);
        Assert.Equal(registeredUser.Email, currentUser.Email);
        Assert.Equal(registeredUser.Roles, currentUser.Roles);

        string encodedResetToken;
        using (var scope = _factory.Services.CreateScope())
        {
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
            var user = await userManager.FindByEmailAsync(email);
            Assert.NotNull(user);
            var resetToken = await userManager.GeneratePasswordResetTokenAsync(user);
            encodedResetToken = WebEncoders.Base64UrlEncode(
                Encoding.UTF8.GetBytes(resetToken));
        }

        const string newPassword = "NewSecurePass2!";
        var resetResponse = await _client.PostAsJsonAsync(
            "/api/auth/reset-password",
            new ResetPasswordRequest(email, encodedResetToken, newPassword));
        Assert.Equal(HttpStatusCode.OK, resetResponse.StatusCode);

        var newPasswordLoginResponse = await _client.PostAsJsonAsync(
            "/api/auth/login",
            new LoginRequest(email, newPassword));
        Assert.Equal(HttpStatusCode.OK, newPasswordLoginResponse.StatusCode);

        using var invalidRequest = new HttpRequestMessage(HttpMethod.Get, "/api/auth/me");
        invalidRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", "invalid-token");
        Assert.Equal(HttpStatusCode.Unauthorized, (await _client.SendAsync(invalidRequest)).StatusCode);

        using var expiredRequest = new HttpRequestMessage(HttpMethod.Get, "/api/auth/me");
        expiredRequest.Headers.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            CreateExpiredToken());
        Assert.Equal(HttpStatusCode.Unauthorized, (await _client.SendAsync(expiredRequest)).StatusCode);
    }

    [Fact]
    public async Task ForgotPasswordDoesNotRevealWhetherAccountExists()
    {
        var knownResponse = await _client.PostAsJsonAsync(
            "/api/auth/forgot-password",
            new EmailRequest("endpoint.test@example.com"));
        var unknownResponse = await _client.PostAsJsonAsync(
            "/api/auth/forgot-password",
            new EmailRequest("unknown@example.com"));

        Assert.Equal(HttpStatusCode.Accepted, knownResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Accepted, unknownResponse.StatusCode);
        Assert.Equal(
            await knownResponse.Content.ReadAsStringAsync(),
            await unknownResponse.Content.ReadAsStringAsync());
    }

    private string CreateExpiredToken()
    {
        var token = new JwtSecurityToken(
            issuer: "AsliApp.Tests",
            audience: "AsliApp.Tests.Client",
            expires: DateTime.UtcNow.AddMinutes(-1),
            signingCredentials: new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_factory.SigningKey)),
                SecurityAlgorithms.HmacSha256));
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static JsonSerializerOptions CreateJsonOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        options.Converters.Add(new JsonStringEnumConverter());
        return options;
    }
}

public sealed class AuthApiFactory : WebApplicationFactory<Program>
{
    private readonly InMemoryDatabaseRoot _databaseRoot = new();

    public string SigningKey { get; } =
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting(
            "ConnectionStrings:DefaultConnection",
            "Server=(localdb)\\MSSQLLocalDB;Database=UnusedByTests");
        builder.UseSetting("Jwt:Issuer", "AsliApp.Tests");
        builder.UseSetting("Jwt:Audience", "AsliApp.Tests.Client");
        builder.UseSetting(
            "Jwt:Key",
            SigningKey);
        builder.UseSetting("Jwt:ExpirationMinutes", "15");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.RemoveAll<DbContextOptions>();
            services.RemoveAll<IDbContextOptionsConfiguration<AppDbContext>>();
            services.RemoveAll<AppDbContext>();
            services.RemoveAll<IEmailSender>();
            services.AddDbContext<AppDbContext>(options =>
                options.UseInMemoryDatabase("AuthEndpoints", _databaseRoot));
            services.AddSingleton<IEmailSender, EndpointEmailSender>();

            using var serviceProvider = services.BuildServiceProvider();
            using var scope = serviceProvider.CreateScope();
            scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.EnsureCreated();
        });
    }
}

public sealed class EndpointEmailSender : IEmailSender
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
