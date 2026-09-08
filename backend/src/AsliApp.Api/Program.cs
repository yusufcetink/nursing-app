using System.Text;
using System.Text.Json.Serialization;
using AsliApp.Api.Administration;
using AsliApp.Api.Authentication;
using AsliApp.Api.Email;
using AsliApp.Api.Education;
using AsliApp.Api.Storage;
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

var builder = WebApplication.CreateBuilder(args);

var fileStorageOptions = builder.Configuration
    .GetRequiredSection(FileStorageOptions.SectionName)
    .Get<FileStorageOptions>()
    ?? throw new InvalidOperationException("FileStorage configuration is missing.");
fileStorageOptions.Validate(builder.Environment.ContentRootPath);
var maxRequestBodySize = checked(fileStorageOptions.MaxFileSizeBytes + 64 * 1024);
builder.WebHost.ConfigureKestrel(options =>
    options.Limits.MaxRequestBodySize = maxRequestBodySize);
builder.Services.Configure<FormOptions>(options =>
    options.MultipartBodyLengthLimit = maxRequestBodySize);
builder.Services.AddSingleton(Options.Create(fileStorageOptions));
builder.Services.AddSingleton<IFileStorage, LocalFileStorage>();

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
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
if (string.IsNullOrWhiteSpace(jwtKey) || Encoding.UTF8.GetByteCount(jwtKey) < 32)
{
    throw new InvalidOperationException(
        "JWT signing key is missing or too short. Configure Jwt__Key with at least 32 bytes.");
}

if (string.IsNullOrWhiteSpace(jwtIssuer) || string.IsNullOrWhiteSpace(jwtAudience))
{
    throw new InvalidOperationException("JWT issuer and audience must be configured.");
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
builder.Services.Configure<GmailSmtpOptions>(
    builder.Configuration.GetSection(GmailSmtpOptions.SectionName));
builder.Services.AddScoped<IEmailSender, GmailSmtpEmailSender>();
builder.Services.AddControllers()
    .AddJsonOptions(options =>
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));

var app = builder.Build();

await AdminBootstrapper.BootstrapAsync(app.Services, app.Configuration);

if (app.Environment.IsDevelopment())
{
    await DevelopmentEducationSeeder.SeedAsync(app.Services);
}

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapGet("/health", () => Results.Ok(new HealthResponse("Healthy")))
    .WithName("Health");

app.Run();

public sealed record HealthResponse(string Status);

public partial class Program;
