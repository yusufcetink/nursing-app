using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using AsliApp.Api.Authentication;
using AsliApp.Domain.Notifications;
using AsliApp.Domain.Tests.Authentication;
using AsliApp.Domain.Users;
using AsliApp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

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
    public void BackendDoesNotRegisterAnInactivityPushWorker()
    {
        using var factory = new AuthApiFactory();
        _ = factory.CreateClient();

        var hostedServices = factory.Services.GetServices<IHostedService>();

        Assert.DoesNotContain(hostedServices, service =>
            service.GetType().Name.Contains("Inactivity", StringComparison.OrdinalIgnoreCase));
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
                NotificationType = "server_push",
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

}
