namespace AsliApp.Domain.Education;

public sealed class LessonContentBlock
{
    public Guid Id { get; set; }
    public Guid LessonId { get; set; }
    public LessonContentBlockType BlockType { get; set; }
    public string? TextContent { get; set; }
    public Guid? MediaId { get; set; }
    public int SortOrder { get; set; }

    public Lesson Lesson { get; set; } = null!;
    public LessonMedia? Media { get; set; }
}

public enum LessonContentBlockType
{
    Heading,
    Text,
    Image,
    Video,
}
