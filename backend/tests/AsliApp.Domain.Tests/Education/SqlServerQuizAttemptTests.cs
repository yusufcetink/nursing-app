using AsliApp.Api.Education;
using AsliApp.Api.Storage;
using AsliApp.Domain.Users;
using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace AsliApp.Domain.Tests.Education;

public sealed class SqlServerQuizFactAttribute : FactAttribute
{
    public SqlServerQuizFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ASLI_TEST_SQLSERVER")))
            Skip = "Set ASLI_TEST_SQLSERVER to a dedicated local test database to exercise SQL constraints and races.";
    }
}

public sealed class SqlServerQuizAttemptTests
{
    [SqlServerQuizFact]
    public async Task MigrationsAndConcurrentStartAndAnswerAreSafeOnSqlServer()
    {
        var connection = Environment.GetEnvironmentVariable("ASLI_TEST_SQLSERVER")!;
        var builder = new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(connection);
        Assert.StartsWith("AsliAppResumeValidation", builder.InitialCatalog);
        var options = new DbContextOptionsBuilder<AppDbContext>().UseSqlServer(connection).Options;
        var storageOptions = Options.Create(new FileStorageOptions
        {
            RootPath = Path.Combine(Path.GetTempPath(), "AsliAppResumeValidationMedia"),
            MaxFileSizeBytes = 26214400,
        });
        var storage = new LocalFileStorage(storageOptions);
        var userId = Guid.NewGuid();
        await using (var db = new AppDbContext(options))
        {
            await db.Database.MigrateAsync();
            await PainLessonSeed.SeedAsync(db, storage);
            await PainLessonSeed.SeedAsync(db, storage);
            db.Users.Add(new User
            {
                Id = userId, Email = $"{userId}@example.test", NormalizedEmail = $"{userId}@EXAMPLE.TEST",
                UserName = userId.ToString(), FirstName = "SQL", LastName = "Test",
            });
            await db.SaveChangesAsync();
            await new EducationService(db, storage, storageOptions)
                .CompleteLessonAsync(userId, PainLessonSeed.LessonId, default);
        }
        async Task<QuizAttemptOutcome> Start()
        {
            await using var db = new AppDbContext(options);
            return await new EducationService(db, storage, storageOptions)
                .GetQuizAttemptAsync(userId, PainLessonSeed.QuizId, true, default);
        }
        var starts = await Task.WhenAll(Enumerable.Range(0, 6).Select(_ => Start()));
        Assert.All(starts, start => Assert.Equal(200, start.StatusCode));
        Assert.Single(starts.Select(s => s.Response!.AttemptId).Distinct());
        var attempt = starts[0].Response!;
        var question = attempt.Quiz.Questions[0];
        async Task<QuizAttemptOutcome> Save(int option)
        {
            await using var db = new AppDbContext(options);
            return await new EducationService(db, storage, storageOptions).SaveQuizAnswerAsync(userId,
                attempt.AttemptId!.Value, new QuizAnswerRequest(question.Id, question.Options[option].Id), default);
        }
        var saves = await Task.WhenAll(Enumerable.Range(0, 6).Select(_ => Save(0)));
        Assert.All(saves, save => Assert.Equal(200, save.StatusCode));
        Assert.Equal(409, (await Save(1)).StatusCode);
        await using var verify = new AppDbContext(options);
        Assert.Equal(1, await verify.QuizAttempts.CountAsync(a => a.UserId == userId));
        Assert.Equal(1, await verify.QuizAttemptAnswers.CountAsync(a => a.QuizAttemptId == attempt.AttemptId));
        Assert.Equal(18, await verify.QuizQuestions.CountAsync(q => q.QuizId == PainLessonSeed.QuizId));
        await new EducationService(verify, storage, storageOptions).ResetQuizAttemptAsync(userId, PainLessonSeed.QuizId, default);
        Assert.False(await verify.QuizAttemptAnswers.AnyAsync(a => a.QuizAttemptId == attempt.AttemptId));
    }
}
