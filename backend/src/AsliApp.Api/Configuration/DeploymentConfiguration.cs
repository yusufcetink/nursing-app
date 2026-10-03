using System.Net;
using Microsoft.AspNetCore.HttpOverrides;

namespace AsliApp.Api.Configuration;

public static class DeploymentConfiguration
{
    public static void ValidateAllowedHosts(string? allowedHosts)
    {
        var hosts = allowedHosts?.Split(';', StringSplitOptions.TrimEntries |
            StringSplitOptions.RemoveEmptyEntries);
        if (hosts is null || hosts.Length == 0 || hosts.Any(host => host.Contains('*')))
        {
            throw new InvalidOperationException(
                "AllowedHosts must contain explicit host names without wildcards for Production.");
        }
    }

    public static void ConfigureForwardedHeaders(
        ForwardedHeadersOptions options, IConfiguration configuration)
    {
        options.ForwardedHeaders = ForwardedHeaders.XForwardedFor |
            ForwardedHeaders.XForwardedProto;
        options.ForwardLimit = 1;
        // Retain the framework's loopback trust; never trust arbitrary upstreams.
        foreach (var proxy in configuration.GetSection("ReverseProxy:KnownProxies")
                     .Get<string[]>() ?? [])
        {
            if (!IPAddress.TryParse(proxy, out var address))
            {
                throw new InvalidOperationException(
                    "ReverseProxy:KnownProxies entries must be IP addresses.");
            }
            options.KnownProxies.Add(address);
        }
    }
}
