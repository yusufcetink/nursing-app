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
    public async Task MultipleQuizzesAreOrderedAndAttemptsAndHistoryRemainIndependent()
    {
        var content = await SeedContentAsync();
        var originalId = await GetQuizIdAsync(content.LessonId);
        var userId = await CreateUserAsync();
        using var student = CreateClient("Student", userId);
        using var admin = CreateClient("Admin");
        using var editor = CreateClient("ContentEditor");
        var listPath = $"/api/education/lessons/{content.LessonId}/quizzes";
        var adminPath = $"/api/education/content/lessons/{content.LessonId}/quizzes";
        Assert.Equal(HttpStatusCode.Forbidden, (await student.GetAsync(adminPath)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await editor.GetAsync(adminPath)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await admin.PostAsJsonAsync(listPath,
            new QuizWriteRequest("Invalid order", false, -1))).StatusCode);

        async Task<Guid> Create(string title, int order)
        {
            var response = await admin.PostAsJsonAsync(listPath, new QuizWriteRequest(title, false, order));
            Assert.Equal(HttpStatusCode.Created, response.StatusCode);
            return (await response.Content.ReadFromJsonAsync<ContentMutationResponse>())!.Id;
        }
        var secondId = await Create("Second quiz", 2);
        var draftId = await Create("Draft quiz", 1);
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.QuizOptions.AddRange(Enumerable.Range(3, 2).Select(i => new QuizOption
            {
                Id = Guid.NewGuid(), QuizQuestionId = content.QuestionId, Order = i, Text = $"Option {i}",
            }));
            db.QuizQuestions.AddRange(Enumerable.Range(1, 2).Select(i => new QuizQuestion
            {
                Id = Guid.NewGuid(), QuizId = secondId, Prompt = $"Second quiz question {i}", Order = i,
                Options = Enumerable.Range(1, 4).Select(j => new QuizOption
                {
                    Id = Guid.NewGuid(), Text = $"Option {j}", Order = j, IsCorrect = j == 1,
                }).ToList(),
            }));
            await db.SaveChangesAsync();
        }
        Assert.Equal(HttpStatusCode.NoContent, (await admin.PutAsJsonAsync(
            $"/api/education/quizzes/{secondId}", new QuizWriteRequest("Second quiz", true, 2))).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await admin.PutAsJsonAsync(
            $"/api/education/quizzes/{originalId}", new QuizWriteRequest("Original quiz", true, 3))).StatusCode);
        var summaries = await student.GetFromJsonAsync<List<QuizSummaryResponse>>(listPath);
        Assert.Equal(new[] { secondId, originalId }, summaries!.Select(q => q.Id));
        var lesson = await student.GetFromJsonAsync<LessonResponse>($"/api/education/lessons/{content.LessonId}");
        Assert.Equal(summaries, lesson!.Quizzes);
        Assert.Equal(new[] { draftId, secondId, originalId },
            (await admin.GetFromJsonAsync<List<QuizSummaryResponse>>(adminPath))!.Select(q => q.Id));
        Assert.Equal(HttpStatusCode.NotFound, (await student.GetAsync($"/api/education/quizzes/{draftId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await student.PostAsync($"/api/education/quizzes/{draftId}/start", null)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await student.GetAsync($"/api/education/lessons/{content.LessonId}/quiz")).StatusCode);

        async Task<QuizAttemptResponse> Start(Guid id)
        {
            var response = await student.PostAsync($"/api/education/quizzes/{id}/start", null);
            response.EnsureSuccessStatusCode();
            return (await response.Content.ReadFromJsonAsync<QuizAttemptResponse>())!;
        }
        Assert.Equal(HttpStatusCode.Forbidden, (await student.PostAsync($"/api/education/quizzes/{originalId}/start", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await student.PostAsync($"/api/education/quizzes/{secondId}/start", null)).StatusCode);
        (await student.PutAsync($"/api/education/lessons/{content.LessonId}/progress", null)).EnsureSuccessStatusCode();
        var original = await Start(originalId);
        var second = await Start(secondId);
        Assert.NotEqual(original.AttemptId, second.AttemptId);
        Assert.Equal(HttpStatusCode.OK, (await Answer(student, second, 0)).StatusCode);
        var resumed = await Start(secondId);
        Assert.Equal(second.AttemptId, resumed.AttemptId);
        Assert.Equal("InProgress", resumed.Status);
        Assert.Single(resumed.Answers);
        Assert.Empty((await Start(originalId)).Answers);
        Assert.Equal(HttpStatusCode.OK, (await Answer(student, original, 0)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await Answer(student, resumed, 1)).StatusCode);
        var completed = await Start(secondId);
        Assert.Equal("Completed", completed.Status);
        Assert.Equal(second.AttemptId, completed.AttemptId);
        Assert.Equal(HttpStatusCode.Conflict, (await Answer(student, completed, 0, 1)).StatusCode);

        var courses = await student.GetFromJsonAsync<List<LeaderboardCourseResponse>>("/api/leaderboard/courses");
        Assert.Equal(2, courses!.Single(c => c.Id == content.ModuleId).QuizCount);
        var leaderboard = await student.GetFromJsonAsync<LeaderboardResponse>(
            $"/api/leaderboard?period=allTime&courseId={content.ModuleId}");
        Assert.Equal(2, leaderboard!.CourseQuizCount);
        Assert.Equal(2, leaderboard.CurrentUser!.CompletedQuizCount);
        var history = await student.GetFromJsonAsync<List<QuizHistoryItemResponse>>("/api/profile/quiz-history");
        Assert.Equal(2, history!.Count);
        Assert.Contains(history, h => h.QuizId == originalId);
        Assert.Contains(history, h => h.QuizId == secondId);

        Assert.Equal(HttpStatusCode.NoContent, (await admin.DeleteAsync($"/api/education/quizzes/{secondId}")).StatusCode);
        Assert.Equal(originalId, Assert.Single((await student.GetFromJsonAsync<List<QuizSummaryResponse>>(listPath))!).Id);
        var detail = await student.GetFromJsonAsync<QuizHistoryDetailResponse>($"/api/profile/quiz-history/{second.AttemptId}");
        Assert.Equal(secondId, detail!.QuizId);
        Assert.Equal(2, detail.TotalQuestionCount);
        Assert.Equal(HttpStatusCode.NoContent, (await admin.DeleteAsync($"/api/education/lessons/{content.LessonId}")).StatusCode);
        using var verifyScope = _factory.Services.CreateScope();
        var verify = verifyScope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.All(await verify.Quizzes.IgnoreQueryFilters().Where(q => q.LessonId == content.LessonId).ToListAsync(),
            q => Assert.True(q.IsDeleted));
        Assert.Equal(2, await verify.QuizAttempts.IgnoreQueryFilters().CountAsync(a => a.UserId == userId));
    }

    [Fact]
    public async Task PublishedLessonWithoutQuizzesReturnsEmptyLists()
    {
        var content = await SeedContentAsync();
        using var admin = CreateClient("Admin");
        using var student = CreateClient("Student");
        await admin.DeleteAsync($"/api/education/quizzes/{await GetQuizIdAsync(content.LessonId)}");
        Assert.Empty((await student.GetFromJsonAsync<List<QuizSummaryResponse>>(
            $"/api/education/lessons/{content.LessonId}/quizzes"))!);
        Assert.Empty((await student.GetFromJsonAsync<LessonResponse>(
            $"/api/education/lessons/{content.LessonId}"))!.Quizzes);
    }
}
