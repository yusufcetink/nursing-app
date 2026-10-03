using System.Text;
using System.Text.Json.Serialization;
using AsliApp.Api.Administration;
using AsliApp.Api.Authentication;
using AsliApp.Api.Analytics;
using AsliApp.Api.Email;
using AsliApp.Api.Education;
using AsliApp.Api.Storage;
using AsliApp.Api.Notifications;
using AsliApp.Domain.Users;
using AsliApp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Extensions.Options;
using System.Security.Claims;
using System.Security.Cryptography;
using AsliApp.Api.Configuration;
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

var allowedHosts = builder.Configuration["AllowedHosts"];
if (builder.Environment.IsProduction())
{
    DeploymentConfiguration.ValidateAllowedHosts(allowedHosts);
}
builder.Services.Configure<ForwardedHeadersOptions>(options =>
    DeploymentConfiguration.ConfigureForwardedHeaders(options, builder.Configuration));
builder.Services.AddHttpsRedirection(options => options.HttpsPort = 443);

var fileStorageOptions = builder.Configuration
    .GetRequiredSection(FileStorageOptions.SectionName)
    .Get<FileStorageOptions>()
    ?? throw new InvalidOperationException("FileStorage configuration is missing.");
var resolvedStorageRoot = fileStorageOptions.ResolveRootPath(builder.Environment.ContentRootPath);
var maxRequestBodySize = checked(fileStorageOptions.MaxFileSizeBytes + 64 * 1024);
builder.WebHost.ConfigureKestrel(options =>
    options.Limits.MaxRequestBodySize = maxRequestBodySize);
builder.Services.Configure<FormOptions>(options =>
    options.MultipartBodyLengthLimit = maxRequestBodySize);
builder.Services.AddSingleton(Options.Create(new FileStorageOptions
{
    RootPath = resolvedStorageRoot,
    MaxFileSizeBytes = fileStorageOptions.MaxFileSizeBytes,
}));
builder.Services.AddSingleton<IFileStorage, LocalFileStorage>();

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        "Database connection string is missing. Configure ConnectionStrings__DefaultConnection.");
}
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connectionString));
builder.Services.AddDataProtection();

builder.Services
    .AddIdentityCore<User>(options =>
    {
        options.User.RequireUniqueEmail = true;
        options.SignIn.RequireConfirmedEmail = true;
        options.Password.RequiredLength = 8;
    })
    .AddRoles<IdentityRole<Guid>>()
    .AddEntityFrameworkStores<AppDbContext>()
    .AddDefaultTokenProviders();

var jwtSection = builder.Configuration.GetSection(JwtOptions.SectionName);
var jwtKey = jwtSection[nameof(JwtOptions.Key)];
var jwtIssuer = jwtSection[nameof(JwtOptions.Issuer)];
var jwtAudience = jwtSection[nameof(JwtOptions.Audience)];
var jwtExpirationMinutes = jwtSection.GetValue<int>(nameof(JwtOptions.ExpirationMinutes));
var refreshTokenExpirationDays = jwtSection.GetValue<int>(
    nameof(JwtOptions.RefreshTokenExpirationDays));
if (string.IsNullOrWhiteSpace(jwtKey) || Encoding.UTF8.GetByteCount(jwtKey) < 32)
{
    throw new InvalidOperationException(
        "JWT signing key is missing or too short. Configure Jwt__Key with at least 32 bytes.");
}

if (string.IsNullOrWhiteSpace(jwtIssuer) || string.IsNullOrWhiteSpace(jwtAudience))
{
    throw new InvalidOperationException("JWT issuer and audience must be configured.");
}

if (jwtExpirationMinutes <= 0 || refreshTokenExpirationDays <= 0)
{
    throw new InvalidOperationException(
        "JWT access and refresh token lifetimes must be greater than zero.");
}

builder.Services.Configure<JwtOptions>(jwtSection);
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            NameClaimType = "sub",
            RoleClaimType = "role",
        };
        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = async context =>
            {
                var userIdValue = context.Principal?.FindFirstValue("sub");
                var tokenStamp = context.Principal?.FindFirstValue("security_stamp");
                if (!Guid.TryParse(userIdValue, out var userId) ||
                    string.IsNullOrEmpty(tokenStamp))
                {
                    context.Fail("The access token is no longer valid.");
                    return;
                }

                var userManager = context.HttpContext.RequestServices
                    .GetRequiredService<UserManager<User>>();
                var user = await userManager.FindByIdAsync(userId.ToString());
                var currentStamp = user is null
                    ? null
                    : await userManager.GetSecurityStampAsync(user);
                if (string.IsNullOrEmpty(currentStamp) ||
                    !CryptographicOperations.FixedTimeEquals(
                        Encoding.UTF8.GetBytes(tokenStamp),
                        Encoding.UTF8.GetBytes(currentStamp)))
                {
                    context.Fail("The access token is no longer valid.");
                }
            },
        };
    });
builder.Services.AddAuthorization();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<AdminUserService>();
builder.Services.AddScoped<IPasswordHasher<EmailVerificationCode>, PasswordHasher<EmailVerificationCode>>();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<EducationService>();
builder.Services.AddScoped<LeaderboardService>();
builder.Services.AddScoped<ActivityService>();
builder.Services.AddScoped<AdminAnalyticsService>();
builder.Services.AddScoped<DeviceRegistrationService>();
builder.Services.AddScoped<NotificationTrackingService>();
builder.Services.Configure<PushNotificationOptions>(
    builder.Configuration.GetSection(PushNotificationOptions.SectionName));
builder.Services.AddSingleton<IPushNotificationSender, FirebasePushNotificationSender>();
builder.Services.Configure<GmailSmtpOptions>(
    builder.Configuration.GetSection(GmailSmtpOptions.SectionName));
builder.Services.AddScoped<IEmailSender, GmailSmtpEmailSender>();
builder.Services.AddControllers()
    .AddJsonOptions(options =>
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddProblemDetails();

var app = builder.Build();

app.UseForwardedHeaders();

await AdminBootstrapper.BootstrapAsync(app.Services, app.Configuration);

if (app.Environment.IsDevelopment())
{
    await DevelopmentEducationSeeder.SeedAsync(app.Services);
}
else
{
    app.UseExceptionHandler();
}

if (app.Environment.IsProduction())
{
    app.UseHsts();
    // Keep the liveness probe reachable over the private HTTP listener.
    app.UseWhen(context => !context.Request.Path.Equals(new PathString("/health")),
        branch => branch.UseHttpsRedirection());
}

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapGet("/health", () => Results.Ok(new HealthResponse("Healthy")))
    .WithName("Health");

app.Run();

public sealed record HealthResponse(string Status);

public partial class Program;
