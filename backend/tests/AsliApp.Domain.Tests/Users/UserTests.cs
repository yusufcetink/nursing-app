using AsliApp.Domain.Users;

namespace AsliApp.Domain.Tests.Users;

public sealed class UserTests
{
    [Fact]
    public void UserUsesGuidIdentityAndKeepsProfileFields()
    {
        var id = Guid.NewGuid();
        var user = new User
        {
            Id = id,
            FirstName = "Aslı",
            LastName = "Yılmaz",
            Email = "asli@example.com",
        };

        Assert.Equal(id, user.Id);
        Assert.Equal("Aslı", user.FirstName);
        Assert.Equal("Yılmaz", user.LastName);
        Assert.Equal("asli@example.com", user.Email);
    }
}
