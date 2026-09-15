using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using AsliApp.Api.Analytics;
using AsliApp.Api.Authentication;
using AsliApp.Domain.Analytics;
using AsliApp.Domain.Users;
using AsliApp.Domain.Tests.Authentication;
using AsliApp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace AsliApp.Domain.Tests.Analytics;

public sealed class ActivityAnalyticsTests
{
    private const string Password = "SecurePass1!";
    private static readonly JsonSerializerOptions JsonOptions = CreateJsonOptions();

    [Fact]
    public async Task BatchIsAuthenticatedOwnedAndIdempotent()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var student = await CreateAndLoginAsync(factory, client, UserRole.Student);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", student.AccessToken);
        var eventId = Guid.NewGuid();
        var sessionId = Guid.NewGuid();
        var request = new ActivityBatchRequest([
            new(eventId, sessionId, "session_start", "home", DateTimeOffset.UtcNow, null, null, null, null, null, null,
                new Dictionary<string, string> { ["source"] = "app", ["password"] = "must-not-persist" }),
        ]);

        var first = await client.PostAsJsonAsync("/api/activity/events/batch", request);
        var second = await client.PostAsJsonAsync("/api/activity/events/batch", request);

        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
        using var scope = factory.Services.CreateScope();
        var events = await scope.ServiceProvider.GetRequiredService<AppDbContext>().UserActivityEvents.ToListAsync();
        var persisted = Assert.Single(events);
        Assert.Equal(student.User.Id, persisted.UserId);
        Assert.DoesNotContain("password", persisted.MetadataJson!, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData(UserRole.Student)]
    [InlineData(UserRole.ContentEditor)]
    public async Task AnalyticsEndpointsRequireAdmin(UserRole role)
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var login = await CreateAndLoginAsync(factory, client, role);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", login.AccessToken);

        Assert.Equal(HttpStatusCode.Forbidden,
            (await client.GetAsync($"/api/admin/analytics/users/{login.User.Id}")).StatusCode);
    }

    [Fact]
    public async Task AdminCanReadAnotherUsersAnalytics()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var student = await CreateAndLoginAsync(factory, client, UserRole.Student);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", student.AccessToken);
        await client.PostAsJsonAsync("/api/activity/events/batch", new ActivityBatchRequest([
            new(Guid.NewGuid(), Guid.NewGuid(), "screen_view", "home", DateTimeOffset.UtcNow, null, null, null, null, null, null, null),
        ]));
        var admin = await CreateAndLoginAsync(factory, client, UserRole.Admin);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", admin.AccessToken);

        var response = await client.GetAsync($"/api/admin/analytics/users/{student.User.Id}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var summary = await response.Content.ReadFromJsonAsync<UserActivitySummaryResponse>();
        Assert.Equal(1, summary!.EventCount);
    }

    [Fact]
    public void SessionDurationUsesLatestForegroundTotalWithoutDoubleCounting()
    {
        Assert.Equal(15, ActivityDurationCalculator.AddActiveSegment(10, 5));
        Assert.Equal(42, ActivityDurationCalculator.SessionDuration(0, 42));
        Assert.Equal(42, ActivityDurationCalculator.SessionDuration(42, 30));
        Assert.Equal(86400, ActivityDurationCalculator.SessionDuration(42, 999999));
    }

    [Fact]
    public async Task DelayedScreenSegmentsAfterSessionEndAreNotDoubleCounted()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var student = await CreateAndLoginAsync(factory, client, UserRole.Student);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", student.AccessToken);
        var sessionId = Guid.NewGuid();
        var now = DateTimeOffset.UtcNow;
        var end = new ActivityBatchRequest([
            new(Guid.NewGuid(), sessionId, "session_end", "home", now, 15, null, null, null, null, null, null),
        ]);
        var segment = new ActivityBatchRequest([
            new(Guid.NewGuid(), sessionId, "screen_leave", "home", now.AddSeconds(-1), 15, null, null, null, null, null, null),
        ]);
        (await client.PostAsJsonAsync("/api/activity/events/batch", end)).EnsureSuccessStatusCode();
        (await client.PostAsJsonAsync("/api/activity/events/batch", segment)).EnsureSuccessStatusCode();
        (await client.PostAsJsonAsync("/api/activity/events/batch", segment)).EnsureSuccessStatusCode();
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(15, (await db.AppSessions.SingleAsync()).ActiveDurationSeconds);
        Assert.Equal(2, await db.UserActivityEvents.CountAsync());
    }

    [Theory]
    [InlineData("999")]
    [InlineData("0")]
    [InlineData("unknown_event")]
    public async Task InvalidEventTypesRejectTheEntireBatch(string invalidType)
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var student = await CreateAndLoginAsync(factory, client, UserRole.Student);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", student.AccessToken);
        var session = Guid.NewGuid();
        var now = DateTimeOffset.UtcNow;
        var response = await client.PostAsJsonAsync("/api/activity/events/batch", new ActivityBatchRequest([
            new(Guid.NewGuid(), session, "session_start", "home", now, null, null, null, null, null, null, null),
            new(Guid.NewGuid(), session, invalidType, "home", now, null, null, null, null, null, null, null),
        ]));
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Empty(await db.UserActivityEvents.ToListAsync());
        Assert.Empty(await db.AppSessions.ToListAsync());
    }

    [Fact]
    public async Task AdminRangeUsesEventTimesAndOnlyScreenSegmentsForDurations()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var student = await CreateAndLoginAsync(factory, client, UserRole.Student);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", student.AccessToken);
        var session = Guid.NewGuid();
        var module = Guid.NewGuid();
        var lesson = Guid.NewGuid();
        var now = DateTimeOffset.UtcNow.AddMinutes(-10);
        (await client.PostAsJsonAsync("/api/activity/events/batch", new ActivityBatchRequest([
            new(Guid.NewGuid(), session, "screen_leave", "lesson", now, 12, module, lesson, null, null, null, null),
            new(Guid.NewGuid(), session, "quiz_complete", "quiz", now, 20, module, lesson, Guid.NewGuid(), null, null, null),
            new(Guid.NewGuid(), session, "video_complete", "lesson", now, 90, module, lesson, null, null, null, null),
            new(Guid.NewGuid(), session, "session_end", "profile", now.AddMinutes(5), 12, null, null, null, null, null, null),
        ]))).EnsureSuccessStatusCode();
        var admin = await CreateAndLoginAsync(factory, client, UserRole.Admin);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", admin.AccessToken);
        // +03:00 and UTC represent the same range, including a session that ends later.
        var from = Uri.EscapeDataString(now.AddSeconds(-1).ToOffset(TimeSpan.FromHours(3)).ToString("O"));
        var to = Uri.EscapeDataString(now.AddSeconds(1).ToString("O"));
        var query = $"?fromUtc={from}&toUtc={to}";
        var summary = await client.GetFromJsonAsync<UserActivitySummaryResponse>($"/api/admin/analytics/users/{student.User.Id}{query}");
        Assert.Equal(12, summary!.ActiveDurationSeconds);
        Assert.Equal(1, summary.SessionCount);
        Assert.Equal(3, summary.EventCount);
        foreach (var endpoint in new[] { "modules", "lessons", "screens" })
        {
            var durations = await client.GetFromJsonAsync<ActivityDurationResponse[]>($"/api/admin/analytics/users/{student.User.Id}/durations/{endpoint}{query}");
            Assert.Equal(12, Assert.Single(durations!).DurationSeconds);
        }
    }

    private static async Task<LoginResponse> CreateAndLoginAsync(AuthApiFactory factory, HttpClient client, UserRole role)
    {
        using var scope = factory.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        var email = $"analytics-{Guid.NewGuid():N}@example.com";
        var user = new User
        {
            Id = Guid.NewGuid(), FirstName = "Analytics", LastName = "User", Email = email, UserName = email,
            EmailConfirmed = true, CreatedAtUtc = DateTimeOffset.UtcNow,
        };
        Assert.True((await userManager.CreateAsync(user, Password)).Succeeded);
        Assert.True((await userManager.AddToRoleAsync(user, role.ToString())).Succeeded);
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
