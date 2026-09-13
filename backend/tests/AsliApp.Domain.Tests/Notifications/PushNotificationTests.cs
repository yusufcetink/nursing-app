using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using AsliApp.Api.Authentication;
using AsliApp.Api.Notifications;
using AsliApp.Domain.Analytics;
using AsliApp.Domain.Notifications;
using AsliApp.Domain.Tests.Authentication;
using AsliApp.Domain.Users;
using AsliApp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace AsliApp.Domain.Tests.Notifications;

public sealed class PushNotificationTests
{
    private const string Password = "SecurePass1!";
    private static readonly JsonSerializerOptions JsonOptions = CreateJsonOptions();

    [Fact]
    public async Task DeviceEndpointsRequireAuthentication()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();

        var register = await client.PutAsJsonAsync("/api/devices/current", new
        {
            installationId = "installation",
            deviceToken = "token",
            platform = "android",
            notificationsEnabled = true,
        });
        var deactivate = await client.PostAsJsonAsync("/api/devices/current/deactivate", new
        {
            installationId = "installation",
        });
        var opened = await client.PostAsync($"/api/notifications/{Guid.NewGuid()}/opened", null);

        Assert.Equal(HttpStatusCode.Unauthorized, register.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, deactivate.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, opened.StatusCode);
    }

    [Fact]
    public async Task DuplicateTokenMovesToTheLatestAuthenticatedUser()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var first = await CreateAndLoginAsync(factory, client);
        await RegisterAsync(client, first.AccessToken, "first-installation", "shared-token");
        var second = await CreateAndLoginAsync(factory, client);

        await RegisterAsync(client, second.AccessToken, "second-installation", "shared-token");

        using var scope = factory.Services.CreateScope();
        var rows = await scope.ServiceProvider.GetRequiredService<AppDbContext>().UserDevices.ToListAsync();
        var device = Assert.Single(rows);
        Assert.Equal(second.User.Id, device.UserId);
        Assert.Equal("second-installation", device.InstallationId);
        Assert.Equal("shared-token", device.DeviceToken);
        Assert.True(device.IsActive);
    }

    [Fact]
    public async Task TokenRefreshUpdatesTheExistingInstallation()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var login = await CreateAndLoginAsync(factory, client);
        await RegisterAsync(client, login.AccessToken, "stable-installation", "old-token");

        await RegisterAsync(client, login.AccessToken, "stable-installation", "new-token");

        using var scope = factory.Services.CreateScope();
        var device = Assert.Single(await scope.ServiceProvider.GetRequiredService<AppDbContext>().UserDevices.ToListAsync());
        Assert.Equal("new-token", device.DeviceToken);
        Assert.Equal("stable-installation", device.InstallationId);
        Assert.True(device.IsActive);
    }

    [Fact]
    public async Task LogoutDeactivateOnlyDisablesTheCurrentUsersInstallation()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var owner = await CreateAndLoginAsync(factory, client);
        await RegisterAsync(client, owner.AccessToken, "owner-installation", "owner-token");
        var other = await CreateAndLoginAsync(factory, client);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", other.AccessToken);

        var otherAttempt = await client.PostAsJsonAsync("/api/devices/current/deactivate", new
        {
            installationId = "owner-installation",
        });
        otherAttempt.EnsureSuccessStatusCode();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", owner.AccessToken);
        var ownerAttempt = await client.PostAsJsonAsync("/api/devices/current/deactivate", new
        {
            installationId = "owner-installation",
        });
        Assert.Equal(HttpStatusCode.NoContent, ownerAttempt.StatusCode);

        using var scope = factory.Services.CreateScope();
        var device = Assert.Single(await scope.ServiceProvider.GetRequiredService<AppDbContext>().UserDevices.ToListAsync());
        Assert.False(device.IsActive);
        Assert.False(device.NotificationsEnabled);
        Assert.Empty(device.DeviceToken);
    }

    [Fact]
    public async Task ReminderHonorsInactivityThresholdAndSuccessfulSendCooldown()
    {
        using var factory = new AuthApiFactory();
        _ = factory.CreateClient();
        var now = new DateTimeOffset(2026, 9, 13, 9, 0, 0, TimeSpan.Zero);
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var dueUser = AddInactiveUser(db, now.AddHours(-48), "due-token");
        var recentUser = AddInactiveUser(db, now.AddHours(-47).AddMinutes(-59), "recent-token");
        await db.SaveChangesAsync();
        var sender = new FakePushSender();
        var clock = new FixedTimeProvider(now);
        var service = new InactivityReminderService(
            db,
            sender,
            Options.Create(new InactivityReminderOptions { AfterHours = 48, CooldownHours = 48 }),
            scope.ServiceProvider.GetRequiredService<IHostEnvironment>(),
            clock);

        Assert.Equal(1, await service.SendDueAsync(CancellationToken.None));
        Assert.Equal(0, await service.SendDueAsync(CancellationToken.None));
        Assert.Single(sender.Messages);
        Assert.Equal("due-token", Assert.Single(sender.Messages[0].Tokens));
        Assert.Equal("Aslı App seni bekliyor 👋", sender.Messages[0].Message.Title);
        Assert.True(Guid.TryParse(sender.Messages[0].Message.Data["notificationId"], out var notificationId));
        var log = await db.PushNotificationLogs.SingleAsync();
        Assert.Equal(notificationId, log.Id);
        Assert.Equal(dueUser.Id, log.UserId);
        Assert.True(log.WasDispatched);
        var sentEvent = await db.UserActivityEvents.SingleAsync();
        Assert.Equal(ActivityEventType.NotificationSent, sentEvent.EventType);
        Assert.Equal(notificationId, sentEvent.ClientEventId);
        Assert.Equal(now.AddHours(-48), (await db.AppSessions.SingleAsync(
            item => item.UserId == dueUser.Id)).LastActivityAtUtc);

        var recentDevice = await db.UserDevices.SingleAsync(item => item.UserId == recentUser.Id);
        recentDevice.IsActive = false;
        await db.SaveChangesAsync();
        clock.UtcNow = now.AddHours(47).AddMinutes(59);
        Assert.Equal(0, await service.SendDueAsync(CancellationToken.None));
        clock.UtcNow = now.AddHours(48);
        Assert.Equal(1, await service.SendDueAsync(CancellationToken.None));
    }

    [Fact]
    public async Task DevelopmentMinuteOverridesControlThresholdAndCooldown()
    {
        using var factory = new AuthApiFactory();
        _ = factory.CreateClient();
        var now = new DateTimeOffset(2026, 9, 13, 9, 0, 0, TimeSpan.Zero);
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var dueUser = AddInactiveUser(db, now.AddMinutes(-2), "development-due-token");
        var recentUser = AddInactiveUser(db, now.AddMinutes(-2).AddSeconds(1), "development-recent-token");
        await db.SaveChangesAsync();
        var sender = new FakePushSender();
        var clock = new FixedTimeProvider(now);
        var service = new InactivityReminderService(
            db,
            sender,
            Options.Create(new InactivityReminderOptions
            {
                AfterHours = 24,
                CooldownHours = 48,
                DevelopmentAfterMinutes = 2,
                DevelopmentCooldownMinutes = 3,
            }),
            new TestHostEnvironment(Environments.Development),
            clock);

        Assert.Equal(1, await service.SendDueAsync(CancellationToken.None));
        Assert.Equal("development-due-token", Assert.Single(sender.Messages[0].Tokens));
        Assert.Single(await db.UserActivityEvents.Where(
            item => item.UserId == dueUser.Id && item.EventType == ActivityEventType.NotificationSent).ToListAsync());
        Assert.Equal(now.AddMinutes(-2), (await db.AppSessions.SingleAsync(
            item => item.UserId == dueUser.Id)).LastActivityAtUtc);

        var recentDevice = await db.UserDevices.SingleAsync(item => item.UserId == recentUser.Id);
        recentDevice.IsActive = false;
        await db.SaveChangesAsync();
        clock.UtcNow = now.AddMinutes(2).AddSeconds(59);
        Assert.Equal(0, await service.SendDueAsync(CancellationToken.None));
        clock.UtcNow = now.AddMinutes(3);
        Assert.Equal(1, await service.SendDueAsync(CancellationToken.None));
        Assert.Equal(2, await db.UserActivityEvents.CountAsync(
            item => item.UserId == dueUser.Id && item.EventType == ActivityEventType.NotificationSent));
    }

    [Fact]
    public async Task ProductionIgnoresDevelopmentMinuteOverrides()
    {
        using var factory = new AuthApiFactory();
        _ = factory.CreateClient();
        var now = new DateTimeOffset(2026, 9, 13, 9, 0, 0, TimeSpan.Zero);
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        _ = AddInactiveUser(db, now.AddMinutes(-10), "production-token");
        await db.SaveChangesAsync();
        var sender = new FakePushSender();
        var service = new InactivityReminderService(
            db,
            sender,
            Options.Create(new InactivityReminderOptions
            {
                AfterHours = 24,
                CooldownHours = 48,
                DevelopmentAfterMinutes = 2,
                DevelopmentCooldownMinutes = 2,
            }),
            new TestHostEnvironment(Environments.Production),
            new FixedTimeProvider(now));

        Assert.Equal(0, await service.SendDueAsync(CancellationToken.None));
        Assert.Empty(sender.Messages);
        Assert.Empty(await db.PushNotificationLogs.ToListAsync());
    }

    [Fact]
    public async Task FailedSendDoesNotStartCooldown()
    {
        using var factory = new AuthApiFactory();
        _ = factory.CreateClient();
        var now = new DateTimeOffset(2026, 9, 13, 9, 0, 0, TimeSpan.Zero);
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        _ = AddInactiveUser(db, now.AddDays(-3), "retry-token");
        await db.SaveChangesAsync();
        var sender = new FakePushSender { Result = false };
        var service = new InactivityReminderService(
            db,
            sender,
            Options.Create(new InactivityReminderOptions { AfterHours = 48, CooldownHours = 48 }),
            scope.ServiceProvider.GetRequiredService<IHostEnvironment>(),
            new FixedTimeProvider(now));

        Assert.Equal(0, await service.SendDueAsync(CancellationToken.None));
        Assert.Equal(0, await service.SendDueAsync(CancellationToken.None));
        Assert.Equal(2, sender.Messages.Count);
        Assert.All(await db.PushNotificationLogs.ToListAsync(), item => Assert.False(item.WasDispatched));
        Assert.Empty(await db.UserActivityEvents.ToListAsync());
    }

    [Fact]
    public async Task NotificationOpenIsRecordedOnlyForItsAuthenticatedOwner()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var owner = await CreateAndLoginAsync(factory, client);
        var other = await CreateAndLoginAsync(factory, client);
        var notificationId = Guid.NewGuid();
        using (var seedScope = factory.Services.CreateScope())
        {
            var db = seedScope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.PushNotificationLogs.Add(new PushNotificationLog
            {
                Id = notificationId,
                UserId = owner.User.Id,
                NotificationType = InactivityReminderService.NotificationType,
                SentAtUtc = DateTimeOffset.UtcNow,
                WasDispatched = true,
            });
            await db.SaveChangesAsync();
        }

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", other.AccessToken);
        Assert.Equal(HttpStatusCode.NoContent,
            (await client.PostAsync($"/api/notifications/{notificationId}/opened", null)).StatusCode);
        using (var verifyScope = factory.Services.CreateScope())
        {
            var db = verifyScope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Null((await db.PushNotificationLogs.SingleAsync()).OpenedAtUtc);
        }

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", owner.AccessToken);
        Assert.Equal(HttpStatusCode.NoContent,
            (await client.PostAsync($"/api/notifications/{notificationId}/opened", null)).StatusCode);
        using var finalScope = factory.Services.CreateScope();
        Assert.NotNull((await finalScope.ServiceProvider.GetRequiredService<AppDbContext>()
            .PushNotificationLogs.SingleAsync()).OpenedAtUtc);
    }

    private static User AddInactiveUser(AppDbContext db, DateTimeOffset lastActivityAtUtc, string token)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            UserName = $"inactive-{Guid.NewGuid():N}@example.com",
            Email = $"inactive-{Guid.NewGuid():N}@example.com",
            FirstName = "Inactive",
            LastName = "User",
            EmailConfirmed = true,
            CreatedAtUtc = lastActivityAtUtc.AddDays(-1),
        };
        db.Users.Add(user);
        db.AppSessions.Add(new AppSession
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            StartedAtUtc = lastActivityAtUtc.AddMinutes(-5),
            LastActivityAtUtc = lastActivityAtUtc,
            ActiveDurationSeconds = 60,
        });
        db.UserDevices.Add(new UserDevice
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            InstallationId = Guid.NewGuid().ToString(),
            DeviceToken = token,
            Platform = "android",
            NotificationsEnabled = true,
            IsActive = true,
            RegisteredAtUtc = lastActivityAtUtc,
            LastUpdatedAtUtc = lastActivityAtUtc,
        });
        return user;
    }

    private static async Task RegisterAsync(HttpClient client, string accessToken, string installationId, string token)
    {
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        var response = await client.PutAsJsonAsync("/api/devices/current", new
        {
            installationId,
            deviceToken = token,
            platform = "android",
            notificationsEnabled = true,
        });
        response.EnsureSuccessStatusCode();
    }

    private static async Task<LoginResponse> CreateAndLoginAsync(AuthApiFactory factory, HttpClient client)
    {
        using var scope = factory.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        var email = $"push-{Guid.NewGuid():N}@example.com";
        var user = new User
        {
            Id = Guid.NewGuid(), FirstName = "Push", LastName = "User", Email = email, UserName = email,
            EmailConfirmed = true, CreatedAtUtc = DateTimeOffset.UtcNow,
        };
        Assert.True((await userManager.CreateAsync(user, Password)).Succeeded);
        Assert.True((await userManager.AddToRoleAsync(user, UserRole.Student.ToString())).Succeeded);
        var response = await client.PostAsJsonAsync("/api/auth/login", new LoginRequest(email, Password));
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<LoginResponse>(JsonOptions))!;
    }

    private static JsonSerializerOptions CreateJsonOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        options.Converters.Add(new JsonStringEnumConverter());
        return options;
    }

    private sealed class FixedTimeProvider(DateTimeOffset utcNow) : TimeProvider
    {
        public DateTimeOffset UtcNow { get; set; } = utcNow;
        public override DateTimeOffset GetUtcNow() => UtcNow;
    }

    private sealed class FakePushSender : IPushNotificationSender
    {
        public bool Result { get; init; } = true;
        public List<(IReadOnlyCollection<string> Tokens, PushMessage Message)> Messages { get; } = [];

        public Task<bool> SendAsync(
            IReadOnlyCollection<string> deviceTokens,
            PushMessage message,
            CancellationToken cancellationToken = default)
        {
            Messages.Add((deviceTokens, message));
            return Task.FromResult(Result);
        }
    }

    private sealed class TestHostEnvironment(string environmentName) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = environmentName;
        public string ApplicationName { get; set; } = "AsliApp.Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
