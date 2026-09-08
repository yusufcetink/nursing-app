using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text;
using AsliApp.Api.Education;
using AsliApp.Api.Storage;
using AsliApp.Domain.Education;
using AsliApp.Infrastructure.Persistence;
using AsliApp.Domain.Users;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Extensions.Options;

namespace AsliApp.Domain.Tests.Education;

public sealed class EducationEndpointsTests : IClassFixture<Authentication.AuthApiFactory>
{
    private readonly Authentication.AuthApiFactory _factory;

    public EducationEndpointsTests(Authentication.AuthApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task StudentReadsOnlyPublishedContentWithoutCorrectAnswers()
    {
        var content = await SeedContentAsync();
        using var client = CreateClient("Student");

        var modulesResponse = await client.GetAsync("/api/education/modules");
        Assert.Equal(HttpStatusCode.OK, modulesResponse.StatusCode);
        var modules = await modulesResponse.Content
            .ReadFromJsonAsync<List<EducationModuleSummaryResponse>>();
        Assert.NotNull(modules);
        Assert.Contains(modules, module => module.Id == content.ModuleId);
        Assert.DoesNotContain(modules, module => module.Id == content.DraftModuleId);

        var module = await client.GetFromJsonAsync<EducationModuleResponse>(
            $"/api/education/modules/{content.ModuleId}");
        Assert.NotNull(module);
        Assert.Single(module.Lessons);
        Assert.Equal(content.LessonId, module.Lessons.Single().Id);

        Assert.Equal(
            HttpStatusCode.NotFound,
            (await client.GetAsync($"/api/education/lessons/{content.DraftLessonId}"))
                .StatusCode);

        var quizResponse = await client.GetAsync(
            $"/api/education/lessons/{content.LessonId}/quiz");
        Assert.Equal(HttpStatusCode.OK, quizResponse.StatusCode);
        var quizJson = await quizResponse.Content.ReadAsStringAsync();
        Assert.DoesNotContain("isCorrect", quizJson, StringComparison.OrdinalIgnoreCase);

        var quiz = await quizResponse.Content.ReadFromJsonAsync<StudentQuizResponse>();
        Assert.NotNull(quiz);
        Assert.Equal(2, quiz.Questions.Single().Options.Count);
    }

    [Fact]
    public async Task StudentCannotCreateContent()
    {
        using var client = CreateClient("Student");
        var id = Guid.NewGuid();
        var requests = new[]
        {
            client.PostAsJsonAsync(
                "/api/education/modules",
                new EducationModuleWriteRequest("Denied", "Denied", 10, false)),
            client.PutAsJsonAsync(
                $"/api/education/modules/{id}",
                new EducationModuleWriteRequest("Denied", "Denied", 10, false)),
            client.PostAsJsonAsync(
                $"/api/education/modules/{id}/lessons",
                new LessonWriteRequest("Denied", "Denied", 1, 0, false)),
            client.PutAsJsonAsync(
                $"/api/education/lessons/{id}",
                new LessonWriteRequest("Denied", "Denied", 1, 0, false)),
            client.PostAsJsonAsync(
                $"/api/education/lessons/{id}/quiz",
                new QuizWriteRequest("Denied", false)),
            client.PutAsJsonAsync(
                $"/api/education/quizzes/{id}",
                new QuizWriteRequest("Denied", false)),
            client.PostAsJsonAsync(
                $"/api/education/quizzes/{id}/questions",
                new QuizQuestionWriteRequest("Denied", 0)),
            client.PutAsJsonAsync(
                $"/api/education/questions/{id}",
                new QuizQuestionWriteRequest("Denied", 0)),
            client.PostAsJsonAsync(
                $"/api/education/questions/{id}/options",
                new QuizOptionWriteRequest("Denied", false, 0)),
            client.PutAsJsonAsync(
                $"/api/education/options/{id}",
                new QuizOptionWriteRequest("Denied", false, 0)),
            client.DeleteAsync($"/api/education/modules/{id}"),
            client.DeleteAsync($"/api/education/lessons/{id}"),
            client.DeleteAsync($"/api/education/quizzes/{id}"),
            client.DeleteAsync($"/api/education/questions/{id}"),
            client.DeleteAsync($"/api/education/lessons/{id}/media/{id}"),
        };

        foreach (var request in requests)
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await request).StatusCode);
        }
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await client.GetAsync("/api/education/content/modules")).StatusCode);
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await client.GetAsync($"/api/education/content/lessons/{Guid.NewGuid()}/quiz"))
                .StatusCode);

        using var upload = CreateMediaUpload([1, 2, 3], "denied.mp4", "video/mp4", 0);
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await client.PostAsync(
                $"/api/education/lessons/{id}/media",
                upload)).StatusCode);
    }

    [Fact]
    public async Task MediaUploadPersistsMetadataStreamsRangesAndDeletesFile()
    {
        var content = await SeedContentAsync();
        using var admin = CreateClient("Admin");
        using var student = CreateClient("Student");
        byte[] videoBytes = [0, 1, 2, 3, 4, 5, 6, 7];

        using var upload = CreateMediaUpload(
            videoBytes,
            "..\\training.mp4",
            "video/mp4",
            3);
        var uploadResponse = await admin.PostAsync(
            $"/api/education/lessons/{content.LessonId}/media",
            upload);
        Assert.Equal(HttpStatusCode.Created, uploadResponse.StatusCode);
        var uploaded = await uploadResponse.Content
            .ReadFromJsonAsync<LessonMediaResponse>();
        Assert.NotNull(uploaded);
        Assert.Equal("training.mp4", uploaded.OriginalFileName);
        Assert.Equal(nameof(LessonMediaType.Video), uploaded.MediaType);
        Assert.Equal(videoBytes.Length, uploaded.SizeBytes);
        Assert.Equal(3, uploaded.SortOrder);
        var blockResponse = await admin.PostAsJsonAsync(
            $"/api/education/lessons/{content.LessonId}/blocks",
            new LessonContentBlockWriteRequest("Video", null, uploaded.Id, 0));
        Assert.Equal(HttpStatusCode.Created, blockResponse.StatusCode);
        var createdBlock = await blockResponse.Content
            .ReadFromJsonAsync<ContentMutationResponse>();
        Assert.NotNull(createdBlock);

        string storageKey;
        using (var scope = _factory.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var metadata = await dbContext.LessonMedia.SingleAsync(
                video => video.Id == uploaded.Id);
            storageKey = metadata.StorageKey;
            Assert.False(Path.IsPathFullyQualified(storageKey));
            Assert.StartsWith("videos/", storageKey, StringComparison.Ordinal);
            Assert.DoesNotContain("..", storageKey, StringComparison.Ordinal);
        }

        var storedPath = Path.Combine(
            _factory.StorageRoot,
            storageKey.Replace('/', Path.DirectorySeparatorChar));
        Assert.True(File.Exists(storedPath));
        Assert.Equal(videoBytes, await File.ReadAllBytesAsync(storedPath));

        var lesson = await student.GetFromJsonAsync<LessonResponse>(
            $"/api/education/lessons/{content.LessonId}");
        Assert.NotNull(lesson);
        Assert.Contains(
            lesson.Blocks,
            block => block.Media?.Id == uploaded.Id && block.BlockType == "Video");

        using var rangeRequest = new HttpRequestMessage(
            HttpMethod.Get,
            $"/api/education/lessons/{content.LessonId}/media/{uploaded.Id}");
        rangeRequest.Headers.Range = new System.Net.Http.Headers.RangeHeaderValue(2, 5);
        var rangeResponse = await student.SendAsync(rangeRequest);
        Assert.Equal(HttpStatusCode.PartialContent, rangeResponse.StatusCode);
        Assert.Equal("bytes", rangeResponse.Content.Headers.ContentRange?.Unit);
        Assert.Equal([2, 3, 4, 5], await rangeResponse.Content.ReadAsByteArrayAsync());

        using var invalidUpload = CreateMediaUpload(
            [1, 2, 3],
            "invalid.mov",
            "video/quicktime",
            0);
        Assert.Equal(
            HttpStatusCode.BadRequest,
            (await admin.PostAsync(
                $"/api/education/lessons/{content.LessonId}/media",
                invalidUpload)).StatusCode);

        using var oversizedUpload = CreateMediaUpload(
            new byte[1025],
            "oversized.mp4",
            "video/mp4",
            0);
        Assert.Equal(
            HttpStatusCode.RequestEntityTooLarge,
            (await admin.PostAsync(
                $"/api/education/lessons/{content.LessonId}/media",
                oversizedUpload)).StatusCode);

        using var draftUpload = CreateMediaUpload(
            [7, 8, 9],
            "draft.mp4",
            "video/mp4",
            0);
        var draftUploadResponse = await admin.PostAsync(
            $"/api/education/lessons/{content.DraftLessonId}/media",
            draftUpload);
        Assert.Equal(HttpStatusCode.Created, draftUploadResponse.StatusCode);
        var draftVideo = await draftUploadResponse.Content
            .ReadFromJsonAsync<LessonMediaResponse>();
        Assert.NotNull(draftVideo);
        Assert.Equal(
            HttpStatusCode.NotFound,
            (await student.GetAsync(
                $"/api/education/lessons/{content.DraftLessonId}/media/{draftVideo.Id}"))
                .StatusCode);

        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await student.DeleteAsync(
                $"/api/education/lessons/{content.LessonId}/media/{uploaded.Id}"))
                .StatusCode);
        Assert.Equal(
            HttpStatusCode.NoContent,
            (await admin.DeleteAsync($"/api/education/blocks/{createdBlock.Id}"))
                .StatusCode);
        Assert.False(File.Exists(storedPath));
        using (var scope = _factory.Services.CreateScope())
        {
            Assert.False(await scope.ServiceProvider
                .GetRequiredService<AppDbContext>()
                .LessonMedia
                .AnyAsync(video => video.Id == uploaded.Id));
        }
    }

    [Theory]
    [InlineData("photo.jpg", "image/jpeg")]
    [InlineData("photo.jpeg", "image/jpeg")]
    [InlineData("diagram.png", "image/png")]
    [InlineData("illustration.webp", "image/webp")]
    public async Task SupportedImagesUseGenericMediaFlow(
        string fileName,
        string contentType)
    {
        var content = await SeedContentAsync();
        using var admin = CreateClient("Admin");
        using var student = CreateClient("Student");
        byte[] imageBytes = [10, 20, 30, 40];

        using var upload = CreateMediaUpload(
            imageBytes,
            fileName,
            contentType,
            2);
        var uploadResponse = await admin.PostAsync(
            $"/api/education/lessons/{content.LessonId}/media",
            upload);
        Assert.Equal(HttpStatusCode.Created, uploadResponse.StatusCode);
        var uploaded = await uploadResponse.Content
            .ReadFromJsonAsync<LessonMediaResponse>();
        Assert.NotNull(uploaded);
        Assert.Equal(nameof(LessonMediaType.Image), uploaded.MediaType);
        Assert.Equal(contentType, uploaded.ContentType);
        var blockResponse = await admin.PostAsJsonAsync(
            $"/api/education/lessons/{content.LessonId}/blocks",
            new LessonContentBlockWriteRequest("Image", null, uploaded.Id, 0));
        Assert.Equal(HttpStatusCode.Created, blockResponse.StatusCode);
        var createdBlock = await blockResponse.Content
            .ReadFromJsonAsync<ContentMutationResponse>();
        Assert.NotNull(createdBlock);

        string storageKey;
        using (var scope = _factory.Services.CreateScope())
        {
            storageKey = await scope.ServiceProvider
                .GetRequiredService<AppDbContext>()
                .LessonMedia
                .Where(media => media.Id == uploaded.Id)
                .Select(media => media.StorageKey)
                .SingleAsync();
        }
        Assert.StartsWith("images/", storageKey, StringComparison.Ordinal);
        Assert.False(Path.IsPathFullyQualified(storageKey));

        var lesson = await student.GetFromJsonAsync<LessonResponse>(
            $"/api/education/lessons/{content.LessonId}");
        Assert.NotNull(lesson);
        Assert.Contains(
            lesson.Blocks,
            block => block.Media?.Id == uploaded.Id && block.BlockType == "Image");

        var readResponse = await student.GetAsync(
            $"/api/education/lessons/{content.LessonId}/media/{uploaded.Id}");
        Assert.Equal(HttpStatusCode.OK, readResponse.StatusCode);
        Assert.Equal(contentType, readResponse.Content.Headers.ContentType?.MediaType);
        Assert.Equal(imageBytes, await readResponse.Content.ReadAsByteArrayAsync());

        Assert.Equal(
            HttpStatusCode.NoContent,
            (await admin.DeleteAsync($"/api/education/blocks/{createdBlock.Id}"))
                .StatusCode);
    }

    [Fact]
    public async Task ContentBlocksSupportCrudValidationAndBulkReorder()
    {
        var content = await SeedContentAsync();
        using var admin = CreateClient("Admin");
        using var student = CreateClient("Student");

        var headingResponse = await admin.PostAsJsonAsync(
            $"/api/education/lessons/{content.LessonId}/blocks",
            new LessonContentBlockWriteRequest("Heading", "Başlık", null, 0));
        var textResponse = await admin.PostAsJsonAsync(
            $"/api/education/lessons/{content.LessonId}/blocks",
            new LessonContentBlockWriteRequest("Text", "Metin", null, 1));
        Assert.Equal(HttpStatusCode.Created, headingResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Created, textResponse.StatusCode);
        var heading = await headingResponse.Content.ReadFromJsonAsync<ContentMutationResponse>();
        var text = await textResponse.Content.ReadFromJsonAsync<ContentMutationResponse>();
        Assert.NotNull(heading);
        Assert.NotNull(text);

        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await student.PostAsJsonAsync(
                $"/api/education/lessons/{content.LessonId}/blocks",
                new LessonContentBlockWriteRequest("Text", "Yetkisiz", null, 2)))
                .StatusCode);
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await student.PutAsJsonAsync(
                $"/api/education/blocks/{heading.Id}",
                new LessonContentBlockWriteRequest("Heading", "Yetkisiz", null, 0)))
                .StatusCode);
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await student.PutAsJsonAsync(
                $"/api/education/lessons/{content.LessonId}/blocks/reorder",
                new LessonContentBlockReorderRequest([
                    new LessonContentBlockOrderRequest(text.Id, 0),
                    new LessonContentBlockOrderRequest(heading.Id, 1),
                ])))
                .StatusCode);

        Assert.Equal(
            HttpStatusCode.BadRequest,
            (await admin.PostAsJsonAsync(
                $"/api/education/lessons/{content.LessonId}/blocks",
                new LessonContentBlockWriteRequest("Image", null, null, 2)))
                .StatusCode);
        Assert.Equal(
            HttpStatusCode.NoContent,
            (await admin.PutAsJsonAsync(
                $"/api/education/blocks/{heading.Id}",
                new LessonContentBlockWriteRequest("Heading", "Yeni başlık", null, 0)))
                .StatusCode);
        Assert.Equal(
            HttpStatusCode.NoContent,
            (await admin.PutAsJsonAsync(
                $"/api/education/lessons/{content.LessonId}/blocks/reorder",
                new LessonContentBlockReorderRequest([
                    new LessonContentBlockOrderRequest(text.Id, 0),
                    new LessonContentBlockOrderRequest(heading.Id, 1),
                ])))
                .StatusCode);

        var lesson = await student.GetFromJsonAsync<LessonResponse>(
            $"/api/education/lessons/{content.LessonId}");
        Assert.NotNull(lesson);
        Assert.Equal([text.Id, heading.Id], lesson.Blocks.Select(block => block.Id));
        Assert.Equal("Yeni başlık", lesson.Blocks[1].TextContent);
        Assert.Equal(
            HttpStatusCode.Forbidden,
            (await student.DeleteAsync($"/api/education/blocks/{text.Id}"))
                .StatusCode);
        Assert.Equal(
            HttpStatusCode.NoContent,
            (await admin.DeleteAsync($"/api/education/blocks/{heading.Id}"))
                .StatusCode);
    }

    [Fact]
    public async Task LocalFileStorageRejectsPathTraversal()
    {
        var root = Path.Combine(Path.GetTempPath(), "AsliApp.StorageTest", Guid.NewGuid().ToString("N"));
        try
        {
            var storage = new LocalFileStorage(Options.Create(new FileStorageOptions
            {
                RootPath = root,
                MaxFileSizeBytes = 1024,
            }));
            await Assert.ThrowsAsync<ArgumentException>(() => storage.WriteAsync(
                "../escaped.mp4",
                new MemoryStream([1, 2, 3])));
        }
        finally
        {
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }

    [Fact]
    public async Task QuizSubmissionIsEvaluatedByServerWithoutLeakingCorrectOption()
    {
        var content = await SeedContentAsync();
        var userId = await CreateUserAsync();
        using var client = CreateClient("Student", userId);

        var response = await client.PostAsJsonAsync(
            $"/api/education/lessons/{content.LessonId}/quiz/submit",
            new QuizSubmissionRequest(
            [
                new QuizAnswerRequest(content.QuestionId, content.CorrectOptionId),
            ]));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("isCorrect", json, StringComparison.OrdinalIgnoreCase);
        var result = await response.Content.ReadFromJsonAsync<QuizSubmissionResponse>();
        Assert.NotNull(result);
        Assert.Equal(1, result.CorrectCount);
        Assert.Equal(0, result.IncorrectCount);
        Assert.Equal(100, result.SuccessPercentage);
        Assert.Equal(1, result.TotalQuestionCount);

        using var scope = _factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var attempt = await dbContext.QuizAttempts
            .Include(candidate => candidate.Answers)
            .SingleAsync(candidate => candidate.Id == result.AttemptId);
        Assert.Equal(userId, attempt.UserId);
        Assert.Single(attempt.Answers);
        Assert.Equal(content.CorrectOptionId, attempt.Answers.Single().SelectedOptionId);

        var history = await client.GetFromJsonAsync<List<QuizHistoryItemResponse>>(
            "/api/profile/quiz-history");
        Assert.NotNull(history);
        Assert.Contains(history, item => item.AttemptId == result.AttemptId);
        var detail = await client.GetFromJsonAsync<QuizHistoryDetailResponse>(
            $"/api/profile/quiz-history/{result.AttemptId}");
        Assert.NotNull(detail);
        Assert.Equal(content.LessonId, detail.LessonId);
    }

    [Fact]
    public async Task LessonCompletionIsIdempotentAndProfileReadsPersistedProgress()
    {
        var content = await SeedContentAsync();
        var userId = await CreateUserAsync();
        using var client = CreateClient("Student", userId);

        var first = await client.PutAsync(
            $"/api/education/lessons/{content.LessonId}/progress",
            null);
        var second = await client.PutAsync(
            $"/api/education/lessons/{content.LessonId}/progress",
            null);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);

        var progress = await client.GetFromJsonAsync<ProgressResponse>(
            "/api/profile/progress");
        Assert.NotNull(progress);
        Assert.Single(progress.CompletedLessons);
        Assert.Equal(content.LessonId, progress.CompletedLessons.Single().LessonId);

        using var scope = _factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(
            1,
            await dbContext.LessonProgress.CountAsync(candidate =>
                candidate.UserId == userId && candidate.LessonId == content.LessonId));
    }

    [Theory]
    [InlineData("ContentEditor")]
    [InlineData("Admin")]
    public async Task AuthorizedContentRolesCanCreateModules(string role)
    {
        using var client = CreateClient(role);

        var response = await client.PostAsJsonAsync(
            "/api/education/modules",
            new EducationModuleWriteRequest(
                $"{role} Module",
                "Authorized content",
                Random.Shared.Next(100, 10000),
                false));

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var createdModule = await response.Content
            .ReadFromJsonAsync<ContentMutationResponse>();
        Assert.NotNull(createdModule);

        var moduleOrder = Random.Shared.Next(100, 10000);
        Assert.Equal(
            HttpStatusCode.NoContent,
            (await client.PutAsJsonAsync(
                $"/api/education/modules/{createdModule.Id}",
                new EducationModuleWriteRequest(
                    $"{role} Updated Module",
                    "Updated authorized content",
                    moduleOrder,
                    true))).StatusCode);
        var lessonResponse = await client.PostAsJsonAsync(
            $"/api/education/modules/{createdModule.Id}/lessons",
            new LessonWriteRequest("Lesson", "Description", 5, 1, false));
        Assert.Equal(HttpStatusCode.Created, lessonResponse.StatusCode);
        var createdLesson = await lessonResponse.Content
            .ReadFromJsonAsync<ContentMutationResponse>();
        Assert.NotNull(createdLesson);
        Assert.Equal(
            HttpStatusCode.NoContent,
            (await client.PutAsJsonAsync(
                $"/api/education/lessons/{createdLesson.Id}",
                new LessonWriteRequest(
                    "Updated lesson",
                    "Updated description",
                    8,
                    2,
                    true))).StatusCode);
        Assert.Equal(
            HttpStatusCode.Created,
            (await client.PostAsJsonAsync(
                $"/api/education/lessons/{createdLesson.Id}/quiz",
                new QuizWriteRequest("Draft quiz", false))).StatusCode);
        using var videoUpload = CreateMediaUpload(
            [0, 1, 2, 3],
            $"{role}.mp4",
            "video/mp4",
            1);
        var videoResponse = await client.PostAsync(
            $"/api/education/lessons/{createdLesson.Id}/media",
            videoUpload);
        Assert.Equal(HttpStatusCode.Created, videoResponse.StatusCode);
        var createdVideo = await videoResponse.Content
            .ReadFromJsonAsync<LessonMediaResponse>();
        Assert.NotNull(createdVideo);
        var blockResponse = await client.PostAsJsonAsync(
            $"/api/education/lessons/{createdLesson.Id}/blocks",
            new LessonContentBlockWriteRequest("Video", null, createdVideo.Id, 0));
        Assert.Equal(HttpStatusCode.Created, blockResponse.StatusCode);
        var createdBlock = await blockResponse.Content
            .ReadFromJsonAsync<ContentMutationResponse>();
        Assert.NotNull(createdBlock);

        var modules = await client
            .GetFromJsonAsync<List<ContentEducationModuleSummaryResponse>>(
                "/api/education/content/modules");
        var module = await client.GetFromJsonAsync<ContentEducationModuleResponse>(
            $"/api/education/content/modules/{createdModule.Id}");
        var lesson = await client.GetFromJsonAsync<ContentLessonResponse>(
            $"/api/education/content/lessons/{createdLesson.Id}");
        Assert.NotNull(modules);
        Assert.NotNull(module);
        Assert.NotNull(lesson);
        Assert.Contains(
            modules,
            item => item.Id == createdModule.Id && item.Order == moduleOrder);
        Assert.Equal(2, module.Lessons.Single().Order);
        Assert.NotNull(lesson.QuizId);
        Assert.Contains(lesson.Blocks, block => block.Media?.Id == createdVideo.Id);
        Assert.Equal(
            HttpStatusCode.NoContent,
            (await client.DeleteAsync($"/api/education/blocks/{createdBlock.Id}"))
                .StatusCode);
    }

    [Theory]
    [InlineData("ContentEditor")]
    [InlineData("Admin")]
    public async Task AuthorizedContentRolesCanReadDraftModulesAndLessons(string role)
    {
        var content = await SeedContentAsync();
        using var client = CreateClient(role);

        var modules = await client.GetFromJsonAsync<List<ContentEducationModuleSummaryResponse>>(
            "/api/education/content/modules");
        Assert.NotNull(modules);
        Assert.Contains(modules, module => module.Id == content.DraftModuleId && !module.IsPublished);

        var module = await client.GetFromJsonAsync<ContentEducationModuleResponse>(
            $"/api/education/content/modules/{content.ModuleId}");
        Assert.NotNull(module);
        Assert.Contains(module.Lessons, lesson =>
            lesson.Id == content.DraftLessonId && !lesson.IsPublished);

        var lesson = await client.GetFromJsonAsync<ContentLessonResponse>(
            $"/api/education/content/lessons/{content.DraftLessonId}");
        Assert.NotNull(lesson);
        Assert.False(lesson.IsPublished);

        var quiz = await client.GetFromJsonAsync<ContentQuizResponse>(
            $"/api/education/content/lessons/{content.LessonId}/quiz");
        Assert.NotNull(quiz);
        Assert.Contains(
            quiz.Questions.Single().Options,
            option => option.Id == content.CorrectOptionId && option.IsCorrect);

        var invalidPublish = await client.PutAsJsonAsync(
            $"/api/education/quizzes/{quiz.Id}",
            new QuizWriteRequest(quiz.Title, true));
        Assert.Equal(HttpStatusCode.BadRequest, invalidPublish.StatusCode);

        Assert.Equal(
            HttpStatusCode.Created,
            (await client.PostAsJsonAsync(
                $"/api/education/questions/{content.QuestionId}/options",
                new QuizOptionWriteRequest("Third option", false, 3))).StatusCode);
        Assert.Equal(
            HttpStatusCode.Created,
            (await client.PostAsJsonAsync(
                $"/api/education/questions/{content.QuestionId}/options",
                new QuizOptionWriteRequest("Fourth option", false, 4))).StatusCode);
        Assert.Equal(
            HttpStatusCode.NoContent,
            (await client.PutAsJsonAsync(
                $"/api/education/quizzes/{quiz.Id}",
                new QuizWriteRequest(quiz.Title, true))).StatusCode);

        var createQuestionResponse = await client.PostAsJsonAsync(
            $"/api/education/quizzes/{quiz.Id}/questions",
            new QuizQuestionWriteRequest("Second question?", 2));
        Assert.Equal(HttpStatusCode.Created, createQuestionResponse.StatusCode);
        var createdQuestion = await createQuestionResponse.Content
            .ReadFromJsonAsync<ContentMutationResponse>();
        Assert.NotNull(createdQuestion);

        Assert.Equal(
            HttpStatusCode.NoContent,
            (await client.PutAsJsonAsync(
                $"/api/education/questions/{content.QuestionId}",
                new QuizQuestionWriteRequest("Question?", 2))).StatusCode);
        Assert.Equal(
            HttpStatusCode.NoContent,
            (await client.PutAsJsonAsync(
                $"/api/education/options/{content.CorrectOptionId}",
                new QuizOptionWriteRequest("Correct", true, 2))).StatusCode);

        var reorderedQuiz = await client.GetFromJsonAsync<ContentQuizResponse>(
            $"/api/education/content/lessons/{content.LessonId}/quiz");
        Assert.NotNull(reorderedQuiz);
        Assert.False(reorderedQuiz.IsPublished);
        Assert.Equal(
            2,
            reorderedQuiz.Questions.Single(question =>
                question.Id == content.QuestionId).Order);
        Assert.Equal(
            1,
            reorderedQuiz.Questions.Single(question =>
                question.Id == createdQuestion.Id).Order);
        var reorderedOptions = reorderedQuiz.Questions.Single(question =>
            question.Id == content.QuestionId).Options;
        Assert.Equal(
            2,
            reorderedOptions.Single(option =>
                option.Id == content.CorrectOptionId).Order);
        Assert.Equal(
            1,
            reorderedOptions.Single(option =>
                option.Id == content.IncorrectOptionId).Order);
    }

    [Fact]
    public async Task DeletesAreSoftCascadeSafelyAndRefreshContentReads()
    {
        var questionContent = await SeedContentAsync();
        var quizContent = await SeedContentAsync();
        var lessonContent = await SeedContentAsync();
        var moduleContent = await SeedContentAsync();
        var userId = await CreateUserAsync();
        using var student = CreateClient("Student", userId);
        using var admin = CreateClient("Admin");

        Assert.Equal(
            HttpStatusCode.OK,
            (await student.PutAsync(
                $"/api/education/lessons/{moduleContent.LessonId}/progress",
                null)).StatusCode);
        var submission = await student.PostAsJsonAsync(
            $"/api/education/lessons/{moduleContent.LessonId}/quiz/submit",
            new QuizSubmissionRequest(
            [
                new QuizAnswerRequest(
                    moduleContent.QuestionId,
                    moduleContent.CorrectOptionId),
            ]));
        Assert.Equal(HttpStatusCode.OK, submission.StatusCode);

        Assert.Equal(
            HttpStatusCode.NoContent,
            (await admin.DeleteAsync(
                $"/api/education/questions/{questionContent.QuestionId}"))
                .StatusCode);
        var questionQuiz = await admin.GetFromJsonAsync<ContentQuizResponse>(
            $"/api/education/content/lessons/{questionContent.LessonId}/quiz");
        Assert.NotNull(questionQuiz);
        Assert.Empty(questionQuiz.Questions);
        Assert.False(questionQuiz.IsPublished);

        Assert.Equal(
            HttpStatusCode.NoContent,
            (await admin.DeleteAsync($"/api/education/quizzes/{await GetQuizIdAsync(quizContent.LessonId)}"))
                .StatusCode);
        Assert.Equal(
            HttpStatusCode.NotFound,
            (await admin.GetAsync(
                $"/api/education/content/lessons/{quizContent.LessonId}/quiz"))
                .StatusCode);
        Assert.Equal(
            HttpStatusCode.Created,
            (await admin.PostAsJsonAsync(
                $"/api/education/lessons/{quizContent.LessonId}/quiz",
                new QuizWriteRequest("Replacement quiz", false))).StatusCode);

        Assert.Equal(
            HttpStatusCode.NoContent,
            (await admin.DeleteAsync($"/api/education/lessons/{lessonContent.LessonId}"))
                .StatusCode);
        var lessonModule = await admin.GetFromJsonAsync<ContentEducationModuleResponse>(
            $"/api/education/content/modules/{lessonContent.ModuleId}");
        Assert.NotNull(lessonModule);
        Assert.DoesNotContain(
            lessonModule.Lessons,
            lesson => lesson.Id == lessonContent.LessonId);

        Assert.Equal(
            HttpStatusCode.NoContent,
            (await admin.DeleteAsync($"/api/education/modules/{moduleContent.ModuleId}"))
                .StatusCode);
        Assert.Equal(
            HttpStatusCode.NotFound,
            (await student.GetAsync($"/api/education/modules/{moduleContent.ModuleId}"))
                .StatusCode);
        var contentModules = await admin
            .GetFromJsonAsync<List<ContentEducationModuleSummaryResponse>>(
                "/api/education/content/modules");
        Assert.NotNull(contentModules);
        Assert.DoesNotContain(contentModules, module => module.Id == moduleContent.ModuleId);

        var progress = await student.GetFromJsonAsync<ProgressResponse>(
            "/api/profile/progress");
        var history = await student.GetFromJsonAsync<List<QuizHistoryItemResponse>>(
            "/api/profile/quiz-history");
        Assert.NotNull(progress);
        Assert.NotNull(history);
        Assert.Contains(
            progress.CompletedLessons,
            item => item.LessonId == moduleContent.LessonId);
        Assert.Contains(history, item => item.LessonId == moduleContent.LessonId);

        using var scope = _factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var deletedModule = await dbContext.EducationModules
            .IgnoreQueryFilters()
            .SingleAsync(module => module.Id == moduleContent.ModuleId);
        var deletedLesson = await dbContext.Lessons
            .IgnoreQueryFilters()
            .SingleAsync(lesson => lesson.Id == moduleContent.LessonId);
        var deletedQuiz = await dbContext.Quizzes
            .IgnoreQueryFilters()
            .SingleAsync(quiz => quiz.LessonId == moduleContent.LessonId);
        var deletedQuestion = await dbContext.QuizQuestions
            .IgnoreQueryFilters()
            .SingleAsync(question => question.Id == moduleContent.QuestionId);
        Assert.True(deletedModule.IsDeleted);
        Assert.True(deletedLesson.IsDeleted);
        Assert.True(deletedQuiz.IsDeleted);
        Assert.True(deletedQuestion.IsDeleted);
        Assert.NotNull(deletedModule.DeletedAtUtc);
    }

    private async Task<Guid> GetQuizIdAsync(Guid lessonId)
    {
        using var scope = _factory.Services.CreateScope();
        return await scope.ServiceProvider.GetRequiredService<AppDbContext>()
            .Quizzes
            .Where(quiz => quiz.LessonId == lessonId)
            .Select(quiz => quiz.Id)
            .SingleAsync();
    }

    private static MultipartFormDataContent CreateMediaUpload(
        byte[] content,
        string fileName,
        string contentType,
        int sortOrder)
    {
        var form = new MultipartFormDataContent();
        var file = new ByteArrayContent(content);
        file.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(contentType);
        form.Add(file, "file", fileName);
        form.Add(new StringContent(sortOrder.ToString()), "sortOrder");
        return form;
    }

    private async Task<SeededContent> SeedContentAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var now = DateTimeOffset.UtcNow;
        var module = new EducationModule
        {
            Id = Guid.NewGuid(),
            Title = "Published module",
            Description = "Published module description",
            Order = 1,
            IsPublished = true,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        var draftModule = new EducationModule
        {
            Id = Guid.NewGuid(),
            Title = "Draft module",
            Description = "Draft module description",
            Order = 2,
            IsPublished = false,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        var lesson = new Lesson
        {
            Id = Guid.NewGuid(),
            EducationModuleId = module.Id,
            Title = "Published lesson",
            Description = "Published lesson description",
            EstimatedDurationMinutes = 10,
            Order = 1,
            IsPublished = true,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        var draftLesson = new Lesson
        {
            Id = Guid.NewGuid(),
            EducationModuleId = module.Id,
            Title = "Draft lesson",
            Description = "Draft lesson description",
            EstimatedDurationMinutes = 5,
            Order = 2,
            IsPublished = false,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        var quiz = new Quiz
        {
            Id = Guid.NewGuid(),
            LessonId = lesson.Id,
            Title = "Published quiz",
            IsPublished = true,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        var question = new QuizQuestion
        {
            Id = Guid.NewGuid(),
            QuizId = quiz.Id,
            Prompt = "Question?",
            Order = 1,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        var correctOption = new QuizOption
        {
            Id = Guid.NewGuid(),
            QuizQuestionId = question.Id,
            Text = "Correct",
            IsCorrect = true,
            Order = 1,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        var incorrectOption = new QuizOption
        {
            Id = Guid.NewGuid(),
            QuizQuestionId = question.Id,
            Text = "Incorrect",
            IsCorrect = false,
            Order = 2,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };

        dbContext.AddRange(
            module,
            draftModule,
            lesson,
            draftLesson,
            quiz,
            question,
            correctOption,
            incorrectOption);
        await dbContext.SaveChangesAsync();
        return new SeededContent(
            module.Id,
            draftModule.Id,
            lesson.Id,
            draftLesson.Id,
            question.Id,
            correctOption.Id,
            incorrectOption.Id);
    }

    private async Task<Guid> CreateUserAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var id = Guid.NewGuid();
        dbContext.Users.Add(new User
        {
            Id = id,
            UserName = $"education-{id}@example.com",
            NormalizedUserName = $"EDUCATION-{id}@EXAMPLE.COM",
            Email = $"education-{id}@example.com",
            NormalizedEmail = $"EDUCATION-{id}@EXAMPLE.COM",
            EmailConfirmed = true,
            FirstName = "Education",
            LastName = "Student",
            CreatedAtUtc = DateTimeOffset.UtcNow,
            SecurityStamp = Guid.NewGuid().ToString(),
            ConcurrencyStamp = Guid.NewGuid().ToString(),
        });
        await dbContext.SaveChangesAsync();
        return id;
    }

    private HttpClient CreateClient(string role, Guid? userId = null)
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            CreateToken(role, userId));
        return client;
    }

    private string CreateToken(string role, Guid? userId = null)
    {
        var token = new JwtSecurityToken(
            issuer: "AsliApp.Tests",
            audience: "AsliApp.Tests.Client",
            claims:
            [
                new Claim("sub", (userId ?? Guid.NewGuid()).ToString()),
                new Claim("email", "education.test@example.com"),
                new Claim("role", role),
            ],
            expires: DateTime.UtcNow.AddMinutes(15),
            signingCredentials: new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_factory.SigningKey)),
                SecurityAlgorithms.HmacSha256));
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private sealed record SeededContent(
        Guid ModuleId,
        Guid DraftModuleId,
        Guid LessonId,
        Guid DraftLessonId,
        Guid QuestionId,
        Guid CorrectOptionId,
        Guid IncorrectOptionId);
}
