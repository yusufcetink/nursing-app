namespace AsliApp.Domain.Education;

public sealed class LessonMedia
{
    public Guid Id { get; set; }
    public Guid LessonId { get; set; }
    public string OriginalFileName { get; set; } = string.Empty;
    public string StorageKey { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public LessonMediaType MediaType { get; set; }
    public long SizeBytes { get; set; }
    public int SortOrder { get; set; }

    public Lesson Lesson { get; set; } = null!;
    public ICollection<LessonContentBlock> ContentBlocks { get; set; } = [];
}

public enum LessonMediaType
{
    Image,
    Video,
}
