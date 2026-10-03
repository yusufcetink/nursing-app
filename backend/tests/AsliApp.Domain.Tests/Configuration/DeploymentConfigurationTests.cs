using System.Net;
using AsliApp.Api.Configuration;
using AsliApp.Api.Storage;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace AsliApp.Domain.Tests.Configuration;

public sealed class DeploymentConfigurationTests
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData(" ; ")]
    [InlineData("*")]
    [InlineData("api.example.com; * ")]
    [InlineData("*.example.com")]
    public void ProductionRejectsWildcardOrMissingHosts(string? hosts)
    {
        Assert.Throws<InvalidOperationException>(() =>
            DeploymentConfiguration.ValidateAllowedHosts(hosts));
    }

    [Fact]
    public void ProductionAcceptsExplicitHostList()
    {
        DeploymentConfiguration.ValidateAllowedHosts("api.example.com;api2.example.com");
    }

    [Theory]
    [InlineData("192.0.2.10", "https")]
    [InlineData("192.0.2.11", "http")]
    public async Task OnlyTrustedProxyCanSetOriginalScheme(string remoteIp, string expectedScheme)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["ReverseProxy:KnownProxies:0"] = "192.0.2.10",
            }).Build();
        var options = new ForwardedHeadersOptions();
        DeploymentConfiguration.ConfigureForwardedHeaders(options, configuration);
        var middleware = new ForwardedHeadersMiddleware(_ => Task.CompletedTask,
            NullLoggerFactory.Instance, Options.Create(options));
        var context = new DefaultHttpContext();
        context.Connection.RemoteIpAddress = IPAddress.Parse(remoteIp);
        context.Request.Scheme = "http";
        context.Request.Headers["X-Forwarded-Proto"] = "https";
        context.Request.Headers["X-Forwarded-For"] = "203.0.113.1";
        await middleware.Invoke(context);
        Assert.Equal(expectedScheme, context.Request.Scheme);
    }

    [Fact]
    public void StorageAcceptsRelativePathWithinAppData()
    {
        var options = new FileStorageOptions
        {
            RootPath = @"App_Data\asliapp-storage",
            MaxFileSizeBytes = 26214400,
        };

        Assert.Equal(
            Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "App_Data", "asliapp-storage")),
            options.ResolveRootPath(AppContext.BaseDirectory));
    }

    [Theory]
    [InlineData("uploads")]
    [InlineData(".")]
    [InlineData(@"..\outside")]
    [InlineData(@"App_Data\..\outside")]
    [InlineData(@"App_Data\..\App_Data\asliapp-storage")]
    public void StorageRejectsRelativePathOutsideAppDataOrWithTraversal(string path)
    {
        Assert.Throws<InvalidOperationException>(() => new FileStorageOptions
        {
            RootPath = path,
            MaxFileSizeBytes = 26214400,
        }.Validate(AppContext.BaseDirectory));
    }

    [Fact]
    public void StorageAcceptsAbsolutePathOutsideApplication()
    {
        var path = Path.Combine(Path.GetTempPath(), "AsliAppStorage", Guid.NewGuid().ToString("N"));
        var options = new FileStorageOptions
        {
            RootPath = path,
            MaxFileSizeBytes = 26214400,
        };

        Assert.Equal(Path.GetFullPath(path), options.ResolveRootPath(AppContext.BaseDirectory));
    }

    [Fact]
    public void StorageRejectsApplicationSubdirectory()
    {
        Assert.Throws<InvalidOperationException>(() => new FileStorageOptions
        {
            RootPath = Path.Combine(AppContext.BaseDirectory, "uploads"),
            MaxFileSizeBytes = 26214400,
        }.Validate(AppContext.BaseDirectory));
    }
}
