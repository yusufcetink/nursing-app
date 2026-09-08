using AsliApp.Domain.Education;
using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AsliApp.Api.Education;

public static class DevelopmentEducationSeeder
{
    private static readonly Guid ModuleId = new("0f16d833-4719-4a80-a0df-46cb1bbd9c31");
    private static readonly Guid LessonId = new("71e61f17-81d5-492b-91d0-3cebe303573a");
    private static readonly Guid QuizId = new("2892ef46-b7fc-4769-8312-20a93b47069b");
    private static readonly Guid QuestionId = new("8481f011-4a66-4e7d-88ce-c33dce45f032");

    public static async Task SeedAsync(
        IServiceProvider services,
        CancellationToken cancellationToken = default)
    {
        await using var scope = services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        if (await dbContext.EducationModules.AnyAsync(
                module => module.Id == ModuleId,
                cancellationToken))
        {
            return;
        }

        var now = DateTimeOffset.UtcNow;
        var module = new EducationModule
        {
            Id = ModuleId,
            Title = "Güvenli Hasta Bakımına Giriş",
            Description = "Temel hasta güvenliği ilkelerini kısa bir dersle öğrenin.",
            Order = 1,
            IsPublished = true,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
            Lessons =
            [
                new Lesson
                {
                    Id = LessonId,
                    Title = "Hasta Kimliğini Doğrulama",
                    Description = "Güvenli bakım öncesinde doğru hastayı doğrulamanın temelleri.",
                    EstimatedDurationMinutes = 5,
                    Order = 1,
                    IsPublished = true,
                    CreatedAtUtc = now,
                    UpdatedAtUtc = now,
                    ContentBlocks =
                    [
                        new LessonContentBlock
                        {
                            Id = new Guid("c818c702-0633-4cc1-aed0-593c6346d55d"),
                            BlockType = LessonContentBlockType.Text,
                            TextContent = "Her işlem öncesinde kurum politikasına uygun en az iki hasta tanımlayıcısı kullanılır. Oda veya yatak numarası tek başına hasta tanımlayıcısı değildir. Hasta bilgileri işlem ve kayıtlarla karşılaştırılır.",
                            SortOrder = 0,
                        },
                    ],
                    Quiz = new Quiz
                    {
                        Id = QuizId,
                        Title = "Hasta Kimliğini Doğrulama Quizi",
                        IsPublished = true,
                        CreatedAtUtc = now,
                        UpdatedAtUtc = now,
                        Questions =
                        [
                            new QuizQuestion
                            {
                                Id = QuestionId,
                                Prompt = "Güvenli hasta kimliği doğrulaması için uygun yaklaşım hangisidir?",
                                Order = 1,
                                CreatedAtUtc = now,
                                UpdatedAtUtc = now,
                                Options =
                                [
                                    CreateOption("c0a029d9-2f0c-4657-b2eb-55094ec0f041", "Yalnızca oda numarasını kullanmak", false, 1, now),
                                    CreateOption("48f7a0de-af32-40a2-93c6-d41cc7bb05ca", "En az iki uygun hasta tanımlayıcısı kullanmak", true, 2, now),
                                    CreateOption("a5dff497-daf7-4b7a-a2b3-2084617b1035", "Hastayı yalnızca yüzünden tanımak", false, 3, now),
                                    CreateOption("831063fa-21b2-4594-b60a-4e8c0f77fa5c", "Doğrulamayı işlem sonrasına bırakmak", false, 4, now),
                                ],
                            },
                        ],
                    },
                },
            ],
        };

        dbContext.EducationModules.Add(module);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static QuizOption CreateOption(
        string id,
        string text,
        bool isCorrect,
        int order,
        DateTimeOffset now) => new()
        {
            Id = new Guid(id),
            Text = text,
            IsCorrect = isCorrect,
            Order = order,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
}
