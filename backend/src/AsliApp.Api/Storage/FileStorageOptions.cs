namespace AsliApp.Api.Storage;

public sealed class FileStorageOptions
{
    public const string SectionName = "FileStorage";

    public string RootPath { get; init; } = string.Empty;
    public long MaxFileSizeBytes { get; init; }

    public void Validate(string contentRootPath) => ResolveRootPath(contentRootPath);

    public string ResolveRootPath(string contentRootPath)
    {
        if (string.IsNullOrWhiteSpace(RootPath))
        {
            throw new InvalidOperationException(
                "FileStorage:RootPath must be configured.");
        }

        if (MaxFileSizeBytes <= 0)
        {
            throw new InvalidOperationException(
                "FileStorage:MaxFileSizeBytes must be greater than zero.");
        }

        var contentRoot = Path.GetFullPath(contentRootPath)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (!Path.IsPathFullyQualified(RootPath) && Path.IsPathRooted(RootPath))
        {
            throw new InvalidOperationException(
                "FileStorage:RootPath must be a fully qualified path or relative to App_Data.");
        }

        if (!Path.IsPathFullyQualified(RootPath))
        {
            var segments = RootPath.Replace('\\', '/').Split('/');
            if (segments.Any(segment => segment == ".." || segment.Contains(':')))
            {
                throw new InvalidOperationException(
                    "FileStorage:RootPath must be within App_Data without traversal.");
            }

            var storageRoot = Path.GetFullPath(Path.Combine(contentRoot,
                    RootPath.Replace('\\', Path.DirectorySeparatorChar)))
                .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            var appDataRoot = Path.Combine(contentRoot, "App_Data");
            var pathWithinAppData = Path.GetRelativePath(appDataRoot, storageRoot);
            if (Path.IsPathRooted(pathWithinAppData) ||
                pathWithinAppData == ".." ||
                pathWithinAppData.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
            {
                throw new InvalidOperationException(
                    "FileStorage:RootPath must be within App_Data.");
            }

            return storageRoot;
        }

        var storageRootAbsolute = Path.GetFullPath(RootPath)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var relativePath = Path.GetRelativePath(contentRoot, storageRootAbsolute);
        if (!Path.IsPathRooted(relativePath) &&
            relativePath != ".." &&
            !relativePath.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                "FileStorage:RootPath must be outside the application content root.");
        }

        return storageRootAbsolute;
    }
}
