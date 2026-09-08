namespace AsliApp.Domain.Education;

public sealed class Lesson
{
    public Guid Id { get; set; }
    public Guid EducationModuleId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int EstimatedDurationMinutes { get; set; }
    public int Order { get; set; }
    public bool IsPublished { get; set; }
    public bool IsDeleted { get; set; }
    public DateTimeOffset? DeletedAtUtc { get; set; }
    public DateTimeOffset CreatedAtUtc { get; set; }
    public DateTimeOffset UpdatedAtUtc { get; set; }

    public EducationModule EducationModule { get; set; } = null!;
    public Quiz? Quiz { get; set; }
    public ICollection<LessonMedia> Media { get; set; } = [];
    public ICollection<LessonContentBlock> ContentBlocks { get; set; } = [];
    public ICollection<LessonProgress> ProgressEntries { get; set; } = [];
}
