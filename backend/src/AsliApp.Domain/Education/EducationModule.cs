namespace AsliApp.Domain.Education;

public sealed class EducationModule
{
    public Guid Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int Order { get; set; }
    public bool IsPublished { get; set; }
    public DateTimeOffset CreatedAtUtc { get; set; }
    public DateTimeOffset UpdatedAtUtc { get; set; }

    public ICollection<Lesson> Lessons { get; set; } = [];
}
