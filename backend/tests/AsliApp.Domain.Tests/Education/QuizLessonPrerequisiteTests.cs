using System.Net;
using System.Net.Http.Json;
using AsliApp.Api.Education;
using AsliApp.Domain.Education;
using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace AsliApp.Domain.Tests.Education;

public sealed partial class EducationEndpointsTests
{
    [Fact]
    public async Task NewAttemptRequiresOwnCompletedProgressForItsLesson()
    {
        var content = await SeedContentAsync();
        var quizId = await GetQuizIdAsync(content.LessonId);
        var userId = await CreateUserAsync();
        var otherUserId = await CreateUserAsync();
        using var student = CreateClient("Student", userId);
        var path = $"/api/education/quizzes/{quizId}";
        Assert.Equal(HttpStatusCode.OK, (await student.GetAsync($"/api/education/lessons/{content.LessonId}")).StatusCode);
        var status = await student.GetFromJsonAsync<QuizAttemptResponse>($"{path}/attempt");
        Assert.Equal("NotStarted", status!.Status);
        Assert.Null(status.AttemptId);
        var blocked = await student.PostAsync($"{path}/start", null);
        Assert.Equal(HttpStatusCode.Forbidden, blocked.StatusCode);
        Assert.Contains("lesson_not_completed", await blocked.Content.ReadAsStringAsync());

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.LessonProgress.AddRange(
                new LessonProgress { Id = Guid.NewGuid(), UserId = otherUserId, LessonId = content.LessonId, IsCompleted = true, CompletedAtUtc = DateTimeOffset.UtcNow },
                new LessonProgress { Id = Guid.NewGuid(), UserId = userId, LessonId = content.DraftLessonId, IsCompleted = true, CompletedAtUtc = DateTimeOffset.UtcNow },
                new LessonProgress { Id = Guid.NewGuid(), UserId = userId, LessonId = content.LessonId, IsCompleted = false });
            db.QuizOptions.AddRange(Enumerable.Range(3, 2).Select(i => new QuizOption
            {
                Id = Guid.NewGuid(), QuizQuestionId = content.QuestionId, Order = i, Text = $"Option {i}",
            }));
            await db.SaveChangesAsync();
        }
        Assert.Equal(HttpStatusCode.Forbidden, (await student.PostAsync($"{path}/start", null)).StatusCode);
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.False(await db.QuizAttempts.AnyAsync(a => a.UserId == userId && a.QuizId == quizId));
        }
        (await student.PutAsync($"/api/education/lessons/{content.LessonId}/progress", null)).EnsureSuccessStatusCode();
        var started = await student.PostAsync($"{path}/start", null);
        started.EnsureSuccessStatusCode();
        var attempt = (await started.Content.ReadFromJsonAsync<QuizAttemptResponse>())!;
        Assert.Equal("InProgress", attempt.Status);
        Assert.NotNull(attempt.AttemptId);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task ExistingAttemptsRemainAccessibleWithoutLessonProgress(bool completed)
    {
        var userId = await CreateUserAsync();
        using var student = CreateClient("Student", userId);
        var attempt = await StartPainQuiz(student);
        var answerCount = completed ? attempt.Quiz.Questions.Count : 1;
        for (var i = 0; i < answerCount; i++)
            (await Answer(student, attempt, i)).EnsureSuccessStatusCode();
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.LessonProgress.RemoveRange(await db.LessonProgress.Where(p => p.UserId == userId).ToListAsync());
            await db.SaveChangesAsync();
        }
        var path = $"/api/education/quizzes/{PainLessonSeed.QuizId}";
        var response = await student.PostAsync($"{path}/start", null);
        response.EnsureSuccessStatusCode();
        var resumed = (await response.Content.ReadFromJsonAsync<QuizAttemptResponse>())!;
        Assert.Equal(attempt.AttemptId, resumed.AttemptId);
        Assert.Equal(completed ? "Completed" : "InProgress", resumed.Status);
        Assert.Equal(answerCount, resumed.AnsweredCount);
        Assert.Equal(resumed.Status, (await student.GetFromJsonAsync<QuizAttemptResponse>($"{path}/attempt"))!.Status);
        if (!completed)
            (await Answer(student, resumed, 1)).EnsureSuccessStatusCode();
        using var verifyScope = _factory.Services.CreateScope();
        var verify = verifyScope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await verify.QuizAttempts.CountAsync(a => a.UserId == userId));
    }
}
