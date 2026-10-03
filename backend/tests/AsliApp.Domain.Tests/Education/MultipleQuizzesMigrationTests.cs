using AsliApp.Domain.Education;
using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace AsliApp.Domain.Tests.Education;

public sealed class MultipleQuizzesMigrationTests
{
    [Fact]
    public void UpgradePreservesQuizAndAttemptRowsAndOnlyRelaxesLessonUniqueness()
    {
        // SQL generation and relational model validation do not require a live database.
        using var db = new AppDbContext(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer().Options);
        var sql = db.GetService<IMigrator>().GenerateScript(
            "20260921201350_QuizAttemptResume", "20260925182335_SupportMultipleQuizzesPerLesson");
        Assert.Contains("DROP INDEX [IX_Quizzes_LessonId]", sql);
        Assert.Contains("ADD [Order] int NOT NULL DEFAULT 0", sql);
        Assert.Contains("CREATE INDEX [IX_Quizzes_LessonId]", sql);
        Assert.DoesNotContain("DELETE FROM", sql, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("DROP TABLE", sql, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("DROP COLUMN", sql, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("QuizAttempts", sql);
        Assert.DoesNotContain("QuizAttemptAnswers", sql);
        var quiz = db.Model.FindEntityType(typeof(Quiz))!;
        Assert.False(quiz.GetForeignKeys().Single(f => f.PrincipalEntityType.ClrType == typeof(Lesson)).IsUnique);
        Assert.False(quiz.GetIndexes().Single(i => i.Properties.Single().Name == nameof(Quiz.LessonId)).IsUnique);
        Assert.True(db.Model.FindEntityType(typeof(QuizAttempt))!.GetIndexes()
            .Single(i => i.Properties.Select(p => p.Name).SequenceEqual(new[] { "UserId", "QuizId" })).IsUnique);
    }
}
