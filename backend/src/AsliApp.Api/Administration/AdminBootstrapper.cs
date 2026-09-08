using AsliApp.Domain.Users;
using Microsoft.AspNetCore.Identity;

namespace AsliApp.Api.Administration;

public static class AdminBootstrapper
{
    public static async Task BootstrapAsync(
        IServiceProvider services,
        IConfiguration configuration)
    {
        var email = configuration["AdminBootstrap:Email"]?.Trim();
        var password = configuration["AdminBootstrap:Password"];
        if (string.IsNullOrWhiteSpace(email) && string.IsNullOrWhiteSpace(password))
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
        {
            throw new InvalidOperationException(
                "Admin bootstrap email and password must be configured together.");
        }

        await using var scope = services.CreateAsyncScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        if ((await userManager.GetUsersInRoleAsync(UserRole.Admin.ToString())).Count > 0)
        {
            return;
        }

        var existingUser = await userManager.FindByEmailAsync(email);
        if (existingUser is not null)
        {
            var existingRoles = await userManager.GetRolesAsync(existingUser);
            if (existingRoles.Count != 0 ||
                !await userManager.CheckPasswordAsync(existingUser, password))
            {
                throw new InvalidOperationException(
                    "Admin bootstrap cannot claim the existing account.");
            }

            await AssignAdminRoleAsync(userManager, existingUser, deleteOnFailure: false);
            return;
        }

        var firstName = configuration["AdminBootstrap:FirstName"]?.Trim();
        var lastName = configuration["AdminBootstrap:LastName"]?.Trim();
        var user = new User
        {
            Id = Guid.NewGuid(),
            FirstName = string.IsNullOrWhiteSpace(firstName) ? "System" : firstName,
            LastName = string.IsNullOrWhiteSpace(lastName) ? "Administrator" : lastName,
            Email = email,
            UserName = email,
            EmailConfirmed = true,
            CreatedAtUtc = DateTimeOffset.UtcNow,
        };
        var createResult = await userManager.CreateAsync(user, password);
        if (!createResult.Succeeded)
        {
            throw new InvalidOperationException(
                $"Admin bootstrap failed: {string.Join(", ", createResult.Errors.Select(error => error.Code))}");
        }

        await AssignAdminRoleAsync(userManager, user, deleteOnFailure: true);
    }

    private static async Task AssignAdminRoleAsync(
        UserManager<User> userManager,
        User user,
        bool deleteOnFailure)
    {
        var roleResult = await userManager.AddToRoleAsync(user, UserRole.Admin.ToString());
        if (!roleResult.Succeeded)
        {
            if (deleteOnFailure)
            {
                await userManager.DeleteAsync(user);
            }
            throw new InvalidOperationException(
                $"Admin bootstrap failed: {string.Join(", ", roleResult.Errors.Select(error => error.Code))}");
        }

        var stampResult = await userManager.UpdateSecurityStampAsync(user);
        if (!stampResult.Succeeded)
        {
            await userManager.RemoveFromRoleAsync(user, UserRole.Admin.ToString());
            if (deleteOnFailure)
            {
                await userManager.DeleteAsync(user);
            }
            throw new InvalidOperationException(
                $"Admin bootstrap failed: {string.Join(", ", stampResult.Errors.Select(error => error.Code))}");
        }
    }
}
