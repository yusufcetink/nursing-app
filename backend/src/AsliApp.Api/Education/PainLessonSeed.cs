using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using AsliApp.Api.Storage;
using AsliApp.Domain.Education;
using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AsliApp.Api.Education;

public static class PainLessonSeed
{
    public static readonly Guid ModuleId = Id("module");
    public static readonly Guid LessonId = Id("lesson");
    public static readonly Guid QuizId = Id("quiz");
    public static string AssetDirectory => Path.Combine(AppContext.BaseDirectory, "Education", "SeedAssets", "Pain");

    public static async Task SeedAsync(AppDbContext db, IFileStorage storage, CancellationToken ct = default)
    {
        // Stable IDs and one atomic DB save. Never overwrite an editor's changes or student history.
        if (await db.Lessons.IgnoreQueryFilters().AnyAsync(l => l.Id == LessonId, ct)) return;
        var data = JsonSerializer.Deserialize<SeedData>(await File.ReadAllTextAsync(
            Path.Combine(AssetDirectory, "lesson.json"), ct), new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
        var now = DateTimeOffset.UtcNow;
        var lesson = new Lesson
        {
            Id = LessonId, EducationModuleId = ModuleId, Title = data.Title,
            Description = "Ağrıyı dinle, türlerini ayırt et; uygun ölçekle değerlendir, kaydet ve yeniden değerlendir.",
            EstimatedDurationMinutes = 22, Order = 1, IsPublished = true, CreatedAtUtc = now, UpdatedAtUtc = now,
        };
        for (var i = 0; i < data.Blocks.Count; i++)
        {
            var block = data.Blocks[i];
            LessonMedia? media = null;
            if (block.Visual is not null)
            {
                var visual = data.Visuals.Single(v => v.Key == block.Visual);
                var key = $"images/pain-v1-{visual.Key}.png";
                var bytes = await File.ReadAllBytesAsync(Path.Combine(AssetDirectory, visual.Key + ".png"), ct);
                await using var existing = await storage.OpenReadAsync(key, ct);
                if (existing is null)
                {
                    await using var content = new MemoryStream(bytes);
                    await storage.WriteAsync(key, content, ct);
                }
                media = new LessonMedia
                {
                    Id = Id("media/" + visual.Key), LessonId = LessonId, OriginalFileName = visual.Title,
                    StorageKey = key, ContentType = "image/png", MediaType = LessonMediaType.Image,
                    SizeBytes = bytes.Length, SortOrder = i,
                };
                lesson.Media.Add(media);
            }
            lesson.ContentBlocks.Add(new LessonContentBlock
            {
                Id = Id("block/" + i), BlockType = Enum.Parse<LessonContentBlockType>(block.Type),
                TextContent = block.Text, SortOrder = i, Media = media,
            });
        }
        lesson.Quizzes = [new Quiz
        {
            Id = QuizId, Title = "Ağrı değerlendirmesi • 18 soruda klinik düşünme",
            IsPublished = true, CreatedAtUtc = now, UpdatedAtUtc = now,
            Questions = data.Questions.Select((q, i) => new QuizQuestion
            {
                Id = Id("question/" + i), Prompt = q.Prompt, Order = i + 1, CreatedAtUtc = now, UpdatedAtUtc = now,
                Options = q.Options.Select((o, j) => new QuizOption
                {
                    Id = Id($"question/{i}/option/{j}"), Text = o, IsCorrect = j == q.CorrectIndex,
                    Order = j + 1, CreatedAtUtc = now, UpdatedAtUtc = now,
                }).ToList(),
            }).ToList(),
        }];
        var module = await db.EducationModules.IgnoreQueryFilters().SingleOrDefaultAsync(m => m.Id == ModuleId, ct);
        if (module is null)
        {
            module = new EducationModule
            {
                Id = ModuleId, Title = "Ağrı ve Konfor", Description = "Hemşirelik öğrencileri için kişi odaklı ağrı değerlendirmesi ve bakım.",
                Order = 2, IsPublished = true, CreatedAtUtc = now, UpdatedAtUtc = now,
            };
            db.EducationModules.Add(module);
        }
        module.Lessons.Add(lesson);
        db.Lessons.Add(lesson);
        await db.SaveChangesAsync(ct);
    }

    private static Guid Id(string key) => new(SHA256.HashData(Encoding.UTF8.GetBytes("asli-app/pain/v1/" + key))[..16]);
    private sealed record SeedData(string Title, List<SeedBlock> Blocks, List<SeedQuestion> Questions, List<SeedVisual> Visuals);
    private sealed record SeedBlock(string Type, string? Text, string? Visual);
    private sealed record SeedQuestion(string Prompt, List<string> Options, int CorrectIndex);
    private sealed record SeedVisual(string Key, string Title);
}
