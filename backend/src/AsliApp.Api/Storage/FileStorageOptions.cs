namespace AsliApp.Api.Storage;

public sealed class FileStorageOptions
{
    public const string SectionName = "FileStorage";

    public string RootPath { get; init; } = string.Empty;
    public long MaxFileSizeBytes { get; init; }

    public void Validate(string contentRootPath)
    {
        if (string.IsNullOrWhiteSpace(RootPath) || !Path.IsPathFullyQualified(RootPath))
        {
            throw new InvalidOperationException(
                "FileStorage:RootPath must be configured as an absolute path.");
        }

        if (MaxFileSizeBytes <= 0)
        {
            throw new InvalidOperationException(
                "FileStorage:MaxFileSizeBytes must be greater than zero.");
        }

        var storageRoot = Path.GetFullPath(RootPath)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var contentRoot = Path.GetFullPath(contentRootPath)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var relativePath = Path.GetRelativePath(contentRoot, storageRoot);
        if (!Path.IsPathRooted(relativePath) &&
            relativePath != ".." &&
            !relativePath.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                "FileStorage:RootPath must be outside the application content root.");
        }
    }
}
