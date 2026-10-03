using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AsliApp.Api.Education;
using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace AsliApp.Domain.Tests.Education;

public sealed partial class EducationEndpointsTests
{
    [Fact]
    public async Task AttemptSnapshotSurvivesQuestionEditsAndDeletionWithoutChangingGrading()
    {
        var content = await SeedContentAsync();
        using var student = CreateClient("Student");
        using var admin = CreateClient("Admin");
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.QuizOptions.AddRange(Enumerable.Range(3, 2).Select(i => new AsliApp.Domain.Education.QuizOption
            {
                Id = Guid.NewGuid(), QuizQuestionId = content.QuestionId, Order = i, Text = $"Option {i}",
            }));
            await db.SaveChangesAsync();
        }
        (await student.PutAsync($"/api/education/lessons/{content.LessonId}/progress", null)).EnsureSuccessStatusCode();
        var start = await student.PostAsync($"/api/education/quizzes/{await GetQuizIdAsync(content.LessonId)}/start", null);
        start.EnsureSuccessStatusCode();
        var attempt = (await start.Content.ReadFromJsonAsync<QuizAttemptResponse>())!;
        Assert.Equal(HttpStatusCode.NoContent, (await admin.PutAsJsonAsync(
            $"/api/education/options/{content.CorrectOptionId}", new QuizOptionWriteRequest("Edited", false, 1))).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await admin.DeleteAsync($"/api/education/questions/{content.QuestionId}")).StatusCode);
        var resumed = await student.GetFromJsonAsync<QuizAttemptResponse>($"/api/education/quizzes/{await GetQuizIdAsync(content.LessonId)}/attempt");
        Assert.Equal(attempt.Quiz.Questions[0].Prompt, resumed!.Quiz.Questions[0].Prompt);
        Assert.Equal("Correct", resumed.Quiz.Questions[0].Options[0].Text);
        var saved = await student.PostAsJsonAsync($"/api/education/quiz-attempts/{attempt.AttemptId}/answers",
            new QuizAnswerRequest(content.QuestionId, content.CorrectOptionId));
        saved.EnsureSuccessStatusCode();
        Assert.Equal(100m, (await saved.Content.ReadFromJsonAsync<QuizAttemptResponse>())!.Result!.SuccessPercentage);
    }

    private async Task<QuizAttemptResponse> StartPainQuiz(HttpClient client)
    {
        await DevelopmentEducationSeeder.SeedAsync(_factory.Services);
        (await client.PutAsync($"/api/education/lessons/{PainLessonSeed.LessonId}/progress", null)).EnsureSuccessStatusCode();
        var response = await client.PostAsync($"/api/education/quizzes/{PainLessonSeed.QuizId}/start", null);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<QuizAttemptResponse>())!;
    }

    private static Task<HttpResponseMessage> Answer(HttpClient client, QuizAttemptResponse attempt, int index, int option = 0) =>
        client.PostAsJsonAsync($"/api/education/quiz-attempts/{attempt.AttemptId}/answers",
            new QuizAnswerRequest(attempt.Quiz.Questions[index].Id, attempt.Quiz.Questions[index].Options[option].Id));

    [Fact]
    public async Task FirstStartPersistsAndSecondStartResumesSameAttemptWithoutLeakingKeys()
    {
        using var client = CreateClient("Student");
        var first = await StartPainQuiz(client);
        var second = await StartPainQuiz(client);
        Assert.Equal("InProgress", first.Status);
        Assert.Equal(first.AttemptId, second.AttemptId);
        Assert.Equal(18, first.Quiz.Questions.Count);
        Assert.Null(first.Result);
        var json = JsonSerializer.Serialize(first);
        Assert.DoesNotContain("IsCorrect", json);
        Assert.DoesNotContain("CorrectOptionId", json);
        Assert.DoesNotContain("AnswerKey", json);
        Assert.DoesNotContain("Snapshot", json);
        using var scope = _factory.Services.CreateScope();
        Assert.Equal(1, await scope.ServiceProvider.GetRequiredService<AppDbContext>().QuizAttempts.CountAsync(a => a.Id == first.AttemptId));
        Assert.Empty((await client.GetFromJsonAsync<List<QuizHistoryItemResponse>>("/api/profile/quiz-history"))!);
    }

    [Fact]
    public async Task SavedAnswerSurvivesResumeIsImmutableAndReplayIsIdempotent()
    {
        using var client = CreateClient("Student");
        var attempt = await StartPainQuiz(client);
        Assert.Equal(HttpStatusCode.OK, (await Answer(client, attempt, 0)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await Answer(client, attempt, 0)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Answer(client, attempt, 0, 1)).StatusCode);
        var resumed = await StartPainQuiz(client);
        Assert.Equal(attempt.AttemptId, resumed.AttemptId);
        Assert.Equal(1, resumed.AnsweredCount);
        Assert.Equal(attempt.Quiz.Questions[0].Options[0].Id, Assert.Single(resumed.Answers).SelectedOptionId);
        Assert.Equal(attempt.Quiz.Questions.Select(q => q.Id), resumed.Quiz.Questions.Select(q => q.Id));
        Assert.Equal(HttpStatusCode.BadRequest, (await Answer(client, attempt, 2)).StatusCode);
        Assert.Null(resumed.Result);
    }

    [Fact]
    public async Task FinalAnswerCompletesAndServerGradesAndCompletedCannotRestartOrChange()
    {
        using var client = CreateClient("Student");
        var attempt = await StartPainQuiz(client);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var keys = await db.QuizOptions.Where(o => o.QuizQuestion.QuizId == PainLessonSeed.QuizId && o.IsCorrect)
            .ToDictionaryAsync(o => o.QuizQuestionId, o => o.Id);
        for (var i = 0; i < 18; i++)
        {
            var question = attempt.Quiz.Questions[i];
            var selected = i < 12 ? keys[question.Id] : question.Options.First(o => o.Id != keys[question.Id]).Id;
            var response = await client.PostAsJsonAsync($"/api/education/quiz-attempts/{attempt.AttemptId}/answers",
                new QuizAnswerRequest(question.Id, selected));
            response.EnsureSuccessStatusCode();
            attempt = (await response.Content.ReadFromJsonAsync<QuizAttemptResponse>())!;
            Assert.Equal(i == 17 ? "Completed" : "InProgress", attempt.Status);
            if (i < 17) Assert.Null(attempt.Result);
        }
        Assert.Equal(12, attempt.Result!.CorrectCount);
        Assert.Equal(6, attempt.Result.IncorrectCount);
        Assert.Equal(66.67m, attempt.Result.SuccessPercentage);
        var restarted = await StartPainQuiz(client);
        Assert.Equal(attempt.AttemptId, restarted.AttemptId);
        Assert.Equal("Completed", restarted.Status);
        var first = attempt.Quiz.Questions[0];
        var alternate = first.Options.First(o => o.Id != keys[first.Id]).Id;
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsJsonAsync(
            $"/api/education/quiz-attempts/{attempt.AttemptId}/answers", new QuizAnswerRequest(first.Id, alternate))).StatusCode);
        var last = attempt.Answers.Single(a => a.QuestionId == attempt.Quiz.Questions[17].Id);
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync(
            $"/api/education/quiz-attempts/{attempt.AttemptId}/answers", last)).StatusCode);
        Assert.Equal(18, await db.QuizAttemptAnswers.CountAsync(a => a.QuizAttemptId == attempt.AttemptId));
    }

    [Fact]
    public async Task AttemptOwnershipAndAdminResetAreEnforced()
    {
        var userId = await CreateUserAsync();
        using var student = CreateClient("Student", userId);
        using var other = CreateClient("Student");
        using var editor = CreateClient("ContentEditor");
        using var admin = CreateClient("Admin");
        var attempt = await StartPainQuiz(student);
        Assert.Equal(HttpStatusCode.NotFound, (await Answer(other, attempt, 0)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await other.GetAsync($"/api/profile/quiz-history/{attempt.AttemptId}")).StatusCode);
        await Answer(student, attempt, 0);
        await student.PutAsync($"/api/education/lessons/{PainLessonSeed.LessonId}/progress", null);
        var reset = $"/api/education/admin/users/{userId}/quizzes/{PainLessonSeed.QuizId}/attempt";
        Assert.Equal(HttpStatusCode.Forbidden, (await student.DeleteAsync(reset)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await editor.DeleteAsync(reset)).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await admin.DeleteAsync(reset)).StatusCode);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False(await db.QuizAttempts.IgnoreQueryFilters().AnyAsync(a => a.Id == attempt.AttemptId));
        Assert.False(await db.QuizAttemptAnswers.IgnoreQueryFilters().AnyAsync(a => a.QuizAttemptId == attempt.AttemptId));
        Assert.False(await db.LessonProgress.AnyAsync(p => p.UserId == userId && p.LessonId == PainLessonSeed.LessonId));
        var status = await student.GetFromJsonAsync<QuizAttemptResponse>($"/api/education/quizzes/{PainLessonSeed.QuizId}/attempt");
        Assert.Equal("NotStarted", status!.Status);
        Assert.NotEqual(attempt.AttemptId, (await StartPainQuiz(student)).AttemptId);
    }

    [Fact]
    public async Task PainSeedIsIdempotentAndIncludesEighteenQuestionsAndEightReadableImages()
    {
        await DevelopmentEducationSeeder.SeedAsync(_factory.Services);
        await DevelopmentEducationSeeder.SeedAsync(_factory.Services);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.Lessons.CountAsync(l => l.Id == PainLessonSeed.LessonId));
        Assert.Equal(1, await db.Quizzes.CountAsync(q => q.Id == PainLessonSeed.QuizId));
        var questions = await db.QuizQuestions.Include(q => q.Options).Where(q => q.QuizId == PainLessonSeed.QuizId).ToListAsync();
        Assert.Equal(18, questions.Count);
        Assert.All(questions, q => { Assert.Equal(4, q.Options.Count); Assert.Single(q.Options, o => o.IsCorrect); });
        using var client = CreateClient("Student");
        var lesson = await client.GetFromJsonAsync<LessonResponse>($"/api/education/lessons/{PainLessonSeed.LessonId}");
        var images = lesson!.Blocks.Where(b => b.Media is not null).ToList();
        Assert.Equal(8, images.Count);
        foreach (var image in images)
        {
            var response = await client.GetAsync($"/api/education/lessons/{PainLessonSeed.LessonId}/media/{image.Media!.Id}");
            Assert.Equal("image/png", response.Content.Headers.ContentType!.MediaType);
            Assert.True((await response.Content.ReadAsByteArrayAsync()).Length > 1000);
        }
    }
}
