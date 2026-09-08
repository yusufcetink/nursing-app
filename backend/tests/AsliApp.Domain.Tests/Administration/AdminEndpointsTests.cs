using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using AsliApp.Api.Administration;
using AsliApp.Api.Authentication;
using AsliApp.Domain.Users;
using AsliApp.Domain.Tests.Authentication;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AsliApp.Domain.Tests.Administration;

public sealed class AdminEndpointsTests
{
    private static readonly JsonSerializerOptions JsonOptions = CreateJsonOptions();

    [Fact]
    public async Task BootstrapCreatesOnlyOneAdminWhenRunRepeatedly()
    {
        using var factory = new AuthApiFactory();
        _ = factory.CreateClient();
        var email = $"bootstrap-{Guid.NewGuid():N}@example.com";
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["AdminBootstrap:Email"] = email,
                ["AdminBootstrap:Password"] = Password,
            })
            .Build();

        await AdminBootstrapper.BootstrapAsync(factory.Services, configuration);
        await AdminBootstrapper.BootstrapAsync(factory.Services, configuration);

        using var scope = factory.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        var admins = await userManager.GetUsersInRoleAsync(nameof(UserRole.Admin));
        Assert.Collection(admins, admin => Assert.Equal(email, admin.Email));
        Assert.True(admins[0].EmailConfirmed);
    }

    [Fact]
    public async Task BootstrapAssignsAdminToMatchingRolelessAccount()
    {
        using var factory = new AuthApiFactory();
        _ = factory.CreateClient();
        using (var scope = factory.Services.CreateScope())
        {
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
            var email = $"roleless-{Guid.NewGuid():N}@example.com";
            var user = new User
            {
                Id = Guid.NewGuid(),
                FirstName = "Roleless",
                LastName = "User",
                Email = email,
                UserName = email,
                EmailConfirmed = true,
                CreatedAtUtc = DateTimeOffset.UtcNow,
            };
            Assert.True((await userManager.CreateAsync(user, Password)).Succeeded);

            var configuration = new ConfigurationBuilder()
                .AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["AdminBootstrap:Email"] = email,
                    ["AdminBootstrap:Password"] = Password,
                })
                .Build();

            await AdminBootstrapper.BootstrapAsync(factory.Services, configuration);
            var persisted = await userManager.FindByIdAsync(user.Id.ToString());
            Assert.NotNull(persisted);
            Assert.Equal([nameof(UserRole.Admin)], await userManager.GetRolesAsync(persisted));
        }
    }

    [Theory]
    [InlineData(UserRole.Student)]
    [InlineData(UserRole.ContentEditor)]
    public async Task UserManagementEndpointsRequireAdminRole(UserRole role)
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var login = await CreateAndLoginAsync(factory, client, role);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            login.AccessToken);

        var response = await client.GetAsync("/api/admin/users");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task AdminCanSearchUsersAndAssignExactlyOneRole()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var admin = await CreateAndLoginAsync(factory, client, UserRole.Admin);
        var target = await CreateUserAsync(factory, UserRole.Student, "Searchable");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            admin.AccessToken);

        var listResponse = await client.GetAsync("/api/admin/users?search=Searchable");
        var users = await listResponse.Content.ReadFromJsonAsync<List<AdminUserResponse>>(JsonOptions);
        var roleResponse = await client.PutAsJsonAsync(
            $"/api/admin/users/{target.Id}/role",
            new ChangeUserRoleRequest(UserRole.ContentEditor));

        Assert.Equal(HttpStatusCode.OK, listResponse.StatusCode);
        Assert.Collection(users!, user => Assert.Equal(target.Id, user.Id));
        Assert.Equal(HttpStatusCode.OK, roleResponse.StatusCode);
        using var scope = factory.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        var persisted = await userManager.FindByIdAsync(target.Id.ToString());
        Assert.NotNull(persisted);
        Assert.Equal([nameof(UserRole.ContentEditor)], await userManager.GetRolesAsync(persisted));
    }

    [Fact]
    public async Task LastAdminCannotBeDemoted()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var login = await CreateAndLoginAsync(factory, client, UserRole.Admin);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            login.AccessToken);

        var response = await client.PutAsJsonAsync(
            $"/api/admin/users/{login.User.Id}/role",
            new ChangeUserRoleRequest(UserRole.Student));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        using var scope = factory.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        var user = await userManager.FindByIdAsync(login.User.Id.ToString());
        Assert.NotNull(user);
        Assert.True(await userManager.IsInRoleAsync(user, nameof(UserRole.Admin)));
    }

    [Fact]
    public async Task RoleChangeInvalidatesOldJwtAndNewLoginGetsNewRole()
    {
        using var factory = new AuthApiFactory();
        using var client = factory.CreateClient();
        var admin = await CreateAndLoginAsync(factory, client, UserRole.Admin);
        var target = await CreateAndLoginAsync(factory, client, UserRole.Student, "Target");

        using var changeRequest = new HttpRequestMessage(
            HttpMethod.Put,
            $"/api/admin/users/{target.User.Id}/role")
        {
            Content = JsonContent.Create(new ChangeUserRoleRequest(UserRole.ContentEditor)),
        };
        changeRequest.Headers.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            admin.AccessToken);
        Assert.Equal(HttpStatusCode.OK, (await client.SendAsync(changeRequest)).StatusCode);

        using var oldTokenRequest = new HttpRequestMessage(
            HttpMethod.Get,
            "/api/education/content/modules");
        oldTokenRequest.Headers.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            target.AccessToken);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await client.SendAsync(oldTokenRequest)).StatusCode);

        var newLoginResponse = await client.PostAsJsonAsync(
            "/api/auth/login",
            new LoginRequest(target.User.Email, Password));
        var newLogin = await newLoginResponse.Content.ReadFromJsonAsync<LoginResponse>(JsonOptions);
        Assert.Equal(HttpStatusCode.OK, newLoginResponse.StatusCode);
        Assert.Equal([UserRole.ContentEditor], newLogin!.User.Roles);
    }

    private const string Password = "SecurePass1!";

    private static async Task<LoginResponse> CreateAndLoginAsync(
        AuthApiFactory factory,
        HttpClient client,
        UserRole role,
        string firstName = "Admin")
    {
        var user = await CreateUserAsync(factory, role, firstName);
        var response = await client.PostAsJsonAsync(
            "/api/auth/login",
            new LoginRequest(user.Email!, Password));
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<LoginResponse>(JsonOptions))!;
    }

    private static async Task<User> CreateUserAsync(
        AuthApiFactory factory,
        UserRole role,
        string firstName)
    {
        using var scope = factory.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        var email = $"{firstName}-{Guid.NewGuid():N}@example.com";
        var user = new User
        {
            Id = Guid.NewGuid(),
            FirstName = firstName,
            LastName = "User",
            Email = email,
            UserName = email,
            EmailConfirmed = true,
            CreatedAtUtc = DateTimeOffset.UtcNow,
        };
        Assert.True((await userManager.CreateAsync(user, Password)).Succeeded);
        Assert.True((await userManager.AddToRoleAsync(user, role.ToString())).Succeeded);
        return user;
    }

    private static JsonSerializerOptions CreateJsonOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        options.Converters.Add(new JsonStringEnumConverter());
        return options;
    }
}
