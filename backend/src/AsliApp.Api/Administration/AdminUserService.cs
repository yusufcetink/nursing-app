using System.Data;
using AsliApp.Domain.Users;
using AsliApp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace AsliApp.Api.Administration;

public sealed class AdminUserService(
    UserManager<User> userManager,
    AppDbContext dbContext)
{
    public async Task<IReadOnlyList<AdminUserResponse>> GetUsersAsync(
        string? search,
        CancellationToken cancellationToken)
    {
        var query = userManager.Users.AsNoTracking();
        var normalizedSearch = search?.Trim();
        if (!string.IsNullOrWhiteSpace(normalizedSearch))
        {
            query = query.Where(user =>
                user.FirstName.Contains(normalizedSearch) ||
                user.LastName.Contains(normalizedSearch) ||
                (user.Email != null && user.Email.Contains(normalizedSearch)));
        }

        var users = await query
            .OrderBy(user => user.FirstName)
            .ThenBy(user => user.LastName)
            .ThenBy(user => user.Email)
            .Take(200)
            .ToListAsync(cancellationToken);
        var responses = new List<AdminUserResponse>(users.Count);
        foreach (var user in users)
        {
            responses.Add(ToResponse(user, await GetSingleRoleAsync(user)));
        }

        return responses;
    }

    public async Task<AdminUserResponse?> GetUserAsync(Guid id)
    {
        var user = await userManager.FindByIdAsync(id.ToString());
        return user is null ? null : ToResponse(user, await GetSingleRoleAsync(user));
    }

    public async Task<ChangeUserRoleResult> ChangeRoleAsync(
        Guid id,
        UserRole newRole,
        CancellationToken cancellationToken)
    {
        IDbContextTransaction? transaction = null;
        if (dbContext.Database.IsRelational())
        {
            transaction = await dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);
        }

        await using (transaction)
        {
            var user = await userManager.FindByIdAsync(id.ToString());
            if (user is null)
            {
                return new(ChangeUserRoleStatus.NotFound);
            }

            var currentRoles = await userManager.GetRolesAsync(user);
            if (currentRoles.Count == 1 && currentRoles[0] == newRole.ToString())
            {
                return new(ChangeUserRoleStatus.Success, ToResponse(user, newRole));
            }

            if (currentRoles.Contains(UserRole.Admin.ToString()) &&
                newRole != UserRole.Admin &&
                await CountAdminsAsync(cancellationToken) <= 1)
            {
                return new(ChangeUserRoleStatus.LastAdmin);
            }

            if (currentRoles.Count > 0)
            {
                var removeResult = await userManager.RemoveFromRolesAsync(user, currentRoles);
                if (!removeResult.Succeeded)
                {
                    return Failed(removeResult);
                }
            }

            var addResult = await userManager.AddToRoleAsync(user, newRole.ToString());
            if (!addResult.Succeeded)
            {
                return Failed(addResult);
            }

            var stampResult = await userManager.UpdateSecurityStampAsync(user);
            if (!stampResult.Succeeded)
            {
                return Failed(stampResult);
            }

            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return new(ChangeUserRoleStatus.Success, ToResponse(user, newRole));
        }
    }

    private async Task<int> CountAdminsAsync(CancellationToken cancellationToken)
    {
        var adminRoleId = await dbContext.Roles
            .Where(role => role.NormalizedName == nameof(UserRole.Admin).ToUpperInvariant())
            .Select(role => role.Id)
            .SingleAsync(cancellationToken);
        return await dbContext.UserRoles.CountAsync(
            userRole => userRole.RoleId == adminRoleId,
            cancellationToken);
    }

    private async Task<UserRole> GetSingleRoleAsync(User user)
    {
        var roles = await userManager.GetRolesAsync(user);
        if (roles.Count != 1 || !Enum.TryParse<UserRole>(roles[0], out var role))
        {
            throw new InvalidOperationException("Every user must have exactly one application role.");
        }

        return role;
    }

    private static ChangeUserRoleResult Failed(IdentityResult result) =>
        new(
            ChangeUserRoleStatus.Failed,
            Errors: result.Errors.Select(error => error.Description).ToArray());

    private static AdminUserResponse ToResponse(User user, UserRole role) =>
        new(
            user.Id,
            user.FirstName,
            user.LastName,
            user.Email ?? string.Empty,
            role);
}
