using System.Net;
using System.Net.Http.Json;
using AsliApp.Api.Education;
using AsliApp.Domain.Education;
using AsliApp.Infrastructure.Persistence;
using Microsoft.Extensions.DependencyInjection;

namespace AsliApp.Domain.Tests.Education;

public sealed partial class EducationEndpointsTests
{
    [Fact]
    public async Task LeaderboardAggregatesCompletedAttemptsAcrossCoursesAndProtectsIdentity()
    {
        var first = await CreateUserAsync();
        var second = await CreateUserAsync();
        var third = await CreateUserAsync();
        using var client = CreateClient("Student", third);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Users.Single(u => u.Id == first).FirstName = "First";
        db.Users.Single(u => u.Id == second).FirstName = "Second";
        db.Users.Single(u => u.Id == third).FirstName = "Third";
        var now = DateTimeOffset.UtcNow;
        var previousMonth = new DateTimeOffset(now.Year, now.Month, 1, 0, 0, 0, TimeSpan.Zero).AddDays(-1);
        var course = new EducationModule { Id = Guid.NewGuid(), Title = "Course A", IsPublished = true };
        var otherCourse = new EducationModule { Id = Guid.NewGuid(), Title = "Course B", IsPublished = true };
        var lessons = Enumerable.Range(0, 4).Select(index => new Lesson
        {
            Id = Guid.NewGuid(), EducationModuleId = index < 2 ? course.Id : otherCourse.Id,
            Title = $"Lesson {index}", IsPublished = true,
        }).ToArray();
        var quizzes = lessons.Select(l => new Quiz
        {
            Id = Guid.NewGuid(), LessonId = l.Id, Title = l.Title, IsPublished = true,
        }).ToArray();
        db.EducationModules.AddRange(course, otherCourse);
        db.Lessons.AddRange(lessons);
        db.Quizzes.AddRange(quizzes);
        db.QuizAttempts.AddRange(
            Attempt(first, quizzes[0].Id, 9, 10, now),
            Attempt(first, quizzes[1].Id, 8, 10, now),
            Attempt(second, quizzes[0].Id, 9, 10, now),
            Attempt(second, quizzes[1].Id, 8, 10, now),
            Attempt(third, quizzes[0].Id, 7, 10, now),
            Attempt(third, quizzes[2].Id, 5, 10, now),
            Attempt(third, quizzes[3].Id, 4, 10, previousMonth),
            Attempt(third, quizzes[1].Id, 10, 10, null),
            Attempt(third, quizzes[1].Id, 4, 10, previousMonth, archived: true));
        await db.SaveChangesAsync();

        var weekly = await client.GetFromJsonAsync<LeaderboardResponse>("/api/leaderboard?period=weekly&limit=1");
        Assert.NotNull(weekly);
        Assert.True(weekly.TotalUsers >= 3);
        Assert.Single(weekly.Entries);
        Assert.True(weekly.CurrentUser!.Rank >= 3);
        Assert.Equal(12, weekly.CurrentUser.TotalCorrectAnswers);
        Assert.Equal(20, weekly.CurrentUser.TotalQuestionCount);
        Assert.Equal(2, weekly.CurrentUser.CompletedQuizCount);
        Assert.Equal(60, weekly.CurrentUser.AccuracyPercentage);
        Assert.Equal("Third Student", weekly.CurrentUser.DisplayName);
        Assert.DoesNotContain("@", weekly.CurrentUser.DisplayName);

        var monthly = await client.GetFromJsonAsync<LeaderboardResponse>("/api/leaderboard?period=monthly");
        Assert.Equal(12, monthly!.CurrentUser!.TotalCorrectAnswers);
        var allTime = await client.GetFromJsonAsync<LeaderboardResponse>("/api/leaderboard?period=allTime");
        Assert.Equal(16, allTime!.CurrentUser!.TotalCorrectAnswers);
        Assert.Equal(30, allTime.CurrentUser.TotalQuestionCount);
        Assert.Equal(3, allTime.CurrentUser.CompletedQuizCount);
        var filtered = await client.GetFromJsonAsync<LeaderboardResponse>(
            $"/api/leaderboard?period=weekly&courseId={course.Id}");
        Assert.Equal(2, filtered!.CourseQuizCount);
        Assert.Equal(3, filtered.TotalUsers);
        Assert.Equal(3, filtered.CurrentUser!.Rank);
        Assert.Equal(string.Compare(first.ToString(), second.ToString(), StringComparison.Ordinal) < 0
            ? "First Student" : "Second Student", filtered.Entries[0].DisplayName);
        Assert.Equal(7, filtered.CurrentUser!.TotalCorrectAnswers);
        Assert.Equal(10, filtered.CurrentUser.TotalQuestionCount);
        Assert.Equal(1, filtered.CurrentUser.CompletedQuizCount);
        Assert.Equal(70, filtered.CurrentUser.AccuracyPercentage);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/api/leaderboard?limit=101")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await client.GetAsync($"/api/leaderboard?courseId={Guid.NewGuid()}")).StatusCode);
        var json = await client.GetStringAsync("/api/leaderboard");
        Assert.DoesNotContain("@example.com", json);
        Assert.DoesNotContain("email", json, StringComparison.OrdinalIgnoreCase);
    }

    private static QuizAttempt Attempt(Guid userId, Guid quizId, int correct, int questions,
        DateTimeOffset? completed, bool archived = false) => new()
    {
        Id = Guid.NewGuid(), UserId = userId, QuizId = quizId,
        CorrectCount = correct, TotalQuestionCount = questions,
        IncorrectCount = questions - correct, StartedAtUtc = DateTimeOffset.UtcNow,
        CompletedAtUtc = completed, IsArchived = archived,
    };

    [Fact]
    public async Task LeaderboardUsesQuizCountThenAccuracyThenStableUserIdForTies()
    {
        var first = await CreateUserAsync();
        var second = await CreateUserAsync();
        var third = await CreateUserAsync();
        var fourth = await CreateUserAsync();
        using var client = CreateClient("Student", fourth);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Users.Single(u => u.Id == first).FirstName = "TieFirst";
        db.Users.Single(u => u.Id == second).FirstName = "TieSecond";
        var course = new EducationModule { Id = Guid.NewGuid(), Title = "Tie course", IsPublished = true };
        var lessons = Enumerable.Range(0, 2).Select(i => new Lesson
        {
            Id = Guid.NewGuid(), EducationModuleId = course.Id,
            Title = $"Tie lesson {i}", IsPublished = true,
        }).ToArray();
        var quizzes = lessons.Select(l => new Quiz
        {
            Id = Guid.NewGuid(), LessonId = l.Id, Title = l.Title, IsPublished = true,
        }).ToArray();
        db.EducationModules.Add(course);
        db.Lessons.AddRange(lessons);
        db.Quizzes.AddRange(quizzes);
        var now = DateTimeOffset.UtcNow;
        db.QuizAttempts.AddRange(
            Attempt(first, quizzes[0].Id, 5, 10, now),
            Attempt(first, quizzes[1].Id, 5, 10, now),
            Attempt(second, quizzes[0].Id, 5, 10, now),
            Attempt(second, quizzes[1].Id, 5, 10, now),
            Attempt(third, quizzes[0].Id, 5, 15, now),
            Attempt(third, quizzes[1].Id, 5, 15, now),
            Attempt(fourth, quizzes[0].Id, 10, 10, now));
        await db.SaveChangesAsync();

        var result = await client.GetFromJsonAsync<LeaderboardResponse>(
            $"/api/leaderboard?period=weekly&courseId={course.Id}");
        Assert.NotNull(result);
        Assert.Equal(4, result.TotalUsers);
        Assert.Equal(4, result.CurrentUser!.Rank);
        Assert.Equal(2, result.Entries[0].CompletedQuizCount);
        Assert.Equal(50, result.Entries[0].AccuracyPercentage);
        Assert.Equal(2, result.Entries[1].CompletedQuizCount);
        Assert.Equal(50, result.Entries[1].AccuracyPercentage);
        Assert.Equal(string.Compare(first.ToString(), second.ToString(), StringComparison.Ordinal) < 0
            ? "TieFirst Student" : "TieSecond Student", result.Entries[0].DisplayName);
        Assert.Equal(2, result.Entries[2].CompletedQuizCount);
        Assert.Equal(33, result.Entries[2].AccuracyPercentage);
        Assert.Equal(1, result.Entries[3].CompletedQuizCount);
        Assert.Equal(100, result.Entries[3].AccuracyPercentage);
    }
}
