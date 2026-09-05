using AsliApp.Domain.Education;
using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AsliApp.Api.Education;

public sealed class EducationService(AppDbContext dbContext)
{
    public async Task<IReadOnlyList<EducationModuleSummaryResponse>> GetModulesAsync(
        CancellationToken cancellationToken)
    {
        return await dbContext.EducationModules
            .AsNoTracking()
            .Where(module => module.IsPublished)
            .OrderBy(module => module.Order)
            .Select(module => new EducationModuleSummaryResponse(
                module.Id,
                module.Title,
                module.Description,
                module.Order,
                module.Lessons.Count(lesson => lesson.IsPublished),
                module.UpdatedAtUtc))
            .ToListAsync(cancellationToken);
    }

    public Task<EducationModuleResponse?> GetModuleAsync(
        Guid id,
        CancellationToken cancellationToken)
    {
        return dbContext.EducationModules
            .AsNoTracking()
            .Where(module => module.Id == id && module.IsPublished)
            .Select(module => new EducationModuleResponse(
                module.Id,
                module.Title,
                module.Description,
                module.Order,
                module.Lessons
                    .Where(lesson => lesson.IsPublished)
                    .OrderBy(lesson => lesson.Order)
                    .Select(lesson => new LessonSummaryResponse(
                        lesson.Id,
                        lesson.Title,
                        lesson.Description,
                        lesson.EstimatedDurationMinutes,
                        lesson.Order))
                    .ToList(),
                module.UpdatedAtUtc))
            .SingleOrDefaultAsync(cancellationToken);
    }

    public Task<LessonResponse?> GetLessonAsync(
        Guid id,
        CancellationToken cancellationToken)
    {
        return dbContext.Lessons
            .AsNoTracking()
            .Where(lesson =>
                lesson.Id == id &&
                lesson.IsPublished &&
                lesson.EducationModule.IsPublished)
            .Select(lesson => new LessonResponse(
                lesson.Id,
                lesson.EducationModuleId,
                lesson.Title,
                lesson.Description,
                lesson.Content,
                lesson.EstimatedDurationMinutes,
                lesson.Order,
                lesson.Quiz != null && lesson.Quiz.IsPublished
                    ? lesson.Quiz.Id
                    : null,
                lesson.UpdatedAtUtc))
            .SingleOrDefaultAsync(cancellationToken);
    }

    public Task<StudentQuizResponse?> GetLessonQuizAsync(
        Guid lessonId,
        CancellationToken cancellationToken)
    {
        return dbContext.Quizzes
            .AsNoTracking()
            .Where(quiz =>
                quiz.LessonId == lessonId &&
                quiz.IsPublished &&
                quiz.Lesson.IsPublished &&
                quiz.Lesson.EducationModule.IsPublished)
            .Select(quiz => new StudentQuizResponse(
                quiz.Id,
                quiz.LessonId,
                quiz.Title,
                quiz.Questions
                    .OrderBy(question => question.Order)
                    .Select(question => new StudentQuizQuestionResponse(
                        question.Id,
                        question.Prompt,
                        question.Order,
                        question.Options
                            .OrderBy(option => option.Order)
                            .Select(option => new StudentQuizOptionResponse(
                                option.Id,
                                option.Text,
                                option.Order))
                            .ToList()))
                    .ToList(),
                quiz.UpdatedAtUtc))
            .SingleOrDefaultAsync(cancellationToken);
    }

    public async Task<QuizSubmissionOutcome> SubmitLessonQuizAsync(
        Guid userId,
        Guid lessonId,
        QuizSubmissionRequest request,
        CancellationToken cancellationToken)
    {
        var quiz = await dbContext.Quizzes
            .Where(candidate =>
                candidate.LessonId == lessonId &&
                candidate.IsPublished &&
                candidate.Lesson.IsPublished &&
                candidate.Lesson.EducationModule.IsPublished)
            .Include(candidate => candidate.Questions)
                .ThenInclude(question => question.Options)
            .SingleOrDefaultAsync(cancellationToken);
        if (quiz is null)
        {
            return QuizSubmissionOutcome.NotFound;
        }

        var answersByQuestion = request.Answers
            .GroupBy(answer => answer.QuestionId)
            .ToDictionary(group => group.Key, group => group.ToList());
        if (answersByQuestion.Count != quiz.Questions.Count ||
            answersByQuestion.Values.Any(answers => answers.Count != 1))
        {
            return QuizSubmissionOutcome.Invalid;
        }

        var evaluatedAnswers = new List<(QuizQuestion Question, QuizOption Option)>();
        var correctCount = 0;
        foreach (var question in quiz.Questions)
        {
            if (!answersByQuestion.TryGetValue(question.Id, out var answers))
            {
                return QuizSubmissionOutcome.Invalid;
            }

            var selectedOption = question.Options.SingleOrDefault(
                option => option.Id == answers[0].SelectedOptionId);
            if (selectedOption is null)
            {
                return QuizSubmissionOutcome.Invalid;
            }

            if (selectedOption.IsCorrect)
            {
                correctCount++;
            }
            evaluatedAnswers.Add((question, selectedOption));
        }

        var incorrectCount = quiz.Questions.Count - correctCount;
        var successPercentage = quiz.Questions.Count == 0
            ? 0
            : Math.Round(
                (decimal)correctCount / quiz.Questions.Count * 100,
                2,
                MidpointRounding.AwayFromZero);
        var completedAtUtc = DateTimeOffset.UtcNow;
        var attempt = new QuizAttempt
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            QuizId = quiz.Id,
            TotalQuestionCount = quiz.Questions.Count,
            CorrectCount = correctCount,
            IncorrectCount = incorrectCount,
            ScorePercentage = successPercentage,
            CompletedAtUtc = completedAtUtc,
            Answers = evaluatedAnswers.Select(evaluated => new QuizAttemptAnswer
            {
                Id = Guid.NewGuid(),
                QuizQuestionId = evaluated.Question.Id,
                SelectedOptionId = evaluated.Option.Id,
                IsCorrect = evaluated.Option.IsCorrect,
            }).ToList(),
        };
        dbContext.QuizAttempts.Add(attempt);
        await dbContext.SaveChangesAsync(cancellationToken);

        return QuizSubmissionOutcome.Success(new QuizSubmissionResponse(
            attempt.Id,
            quiz.Id,
            quiz.Questions.Count,
            correctCount,
            incorrectCount,
            successPercentage,
            completedAtUtc));
    }

    public async Task<LessonCompletionResponse?> CompleteLessonAsync(
        Guid userId,
        Guid lessonId,
        CancellationToken cancellationToken)
    {
        var lesson = await dbContext.Lessons
            .AsNoTracking()
            .Where(candidate =>
                candidate.Id == lessonId &&
                candidate.IsPublished &&
                candidate.EducationModule.IsPublished)
            .Select(candidate => new
            {
                candidate.Id,
                candidate.EducationModuleId,
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (lesson is null)
        {
            return null;
        }

        var progress = await dbContext.LessonProgress.SingleOrDefaultAsync(
            candidate => candidate.UserId == userId && candidate.LessonId == lessonId,
            cancellationToken);
        if (progress is null)
        {
            progress = new LessonProgress
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                LessonId = lessonId,
                IsCompleted = true,
                CompletedAtUtc = DateTimeOffset.UtcNow,
            };
            dbContext.LessonProgress.Add(progress);
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        else if (!progress.IsCompleted)
        {
            progress.IsCompleted = true;
            progress.CompletedAtUtc = DateTimeOffset.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return new LessonCompletionResponse(
            lesson.Id,
            lesson.EducationModuleId,
            progress.CompletedAtUtc!.Value);
    }

    public async Task<ProgressResponse> GetProgressAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var lessons = await dbContext.LessonProgress
            .AsNoTracking()
            .Where(progress => progress.UserId == userId && progress.IsCompleted)
            .OrderBy(progress => progress.CompletedAtUtc)
            .Select(progress => new CompletedLessonResponse(
                progress.LessonId,
                progress.Lesson.EducationModuleId,
                progress.CompletedAtUtc!.Value))
            .ToListAsync(cancellationToken);
        return new ProgressResponse(lessons);
    }

    public async Task<IReadOnlyList<QuizHistoryItemResponse>> GetQuizHistoryAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        return await dbContext.QuizAttempts
            .AsNoTracking()
            .Where(attempt => attempt.UserId == userId)
            .OrderByDescending(attempt => attempt.CompletedAtUtc)
            .Select(attempt => new QuizHistoryItemResponse(
                attempt.Id,
                attempt.QuizId,
                attempt.Quiz.LessonId,
                attempt.Quiz.Title,
                attempt.Quiz.Lesson.Title,
                attempt.TotalQuestionCount,
                attempt.CorrectCount,
                attempt.IncorrectCount,
                attempt.ScorePercentage,
                attempt.CompletedAtUtc))
            .ToListAsync(cancellationToken);
    }

    public Task<QuizHistoryDetailResponse?> GetQuizHistoryDetailAsync(
        Guid userId,
        Guid attemptId,
        CancellationToken cancellationToken)
    {
        return dbContext.QuizAttempts
            .AsNoTracking()
            .Where(attempt => attempt.Id == attemptId && attempt.UserId == userId)
            .Select(attempt => new QuizHistoryDetailResponse(
                attempt.Id,
                attempt.QuizId,
                attempt.Quiz.LessonId,
                attempt.Quiz.Title,
                attempt.Quiz.Lesson.Title,
                attempt.TotalQuestionCount,
                attempt.CorrectCount,
                attempt.IncorrectCount,
                attempt.ScorePercentage,
                attempt.CompletedAtUtc))
            .SingleOrDefaultAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<ContentEducationModuleSummaryResponse>> GetContentModulesAsync(
        CancellationToken cancellationToken)
    {
        return await dbContext.EducationModules
            .AsNoTracking()
            .OrderBy(module => module.Order)
            .ThenBy(module => module.Title)
            .Select(module => new ContentEducationModuleSummaryResponse(
                module.Id,
                module.Title,
                module.Description,
                module.Order,
                module.IsPublished,
                module.Lessons.Count,
                module.UpdatedAtUtc))
            .ToListAsync(cancellationToken);
    }

    public Task<ContentEducationModuleResponse?> GetContentModuleAsync(
        Guid id,
        CancellationToken cancellationToken)
    {
        return dbContext.EducationModules
            .AsNoTracking()
            .Where(module => module.Id == id)
            .Select(module => new ContentEducationModuleResponse(
                module.Id,
                module.Title,
                module.Description,
                module.Order,
                module.IsPublished,
                module.Lessons
                    .OrderBy(lesson => lesson.Order)
                    .ThenBy(lesson => lesson.Title)
                    .Select(lesson => new ContentLessonSummaryResponse(
                        lesson.Id,
                        lesson.Title,
                        lesson.Description,
                        lesson.EstimatedDurationMinutes,
                        lesson.Order,
                        lesson.IsPublished))
                    .ToList(),
                module.UpdatedAtUtc))
            .SingleOrDefaultAsync(cancellationToken);
    }

    public Task<ContentLessonResponse?> GetContentLessonAsync(
        Guid id,
        CancellationToken cancellationToken)
    {
        return dbContext.Lessons
            .AsNoTracking()
            .Where(lesson => lesson.Id == id)
            .Select(lesson => new ContentLessonResponse(
                lesson.Id,
                lesson.EducationModuleId,
                lesson.Title,
                lesson.Description,
                lesson.Content,
                lesson.EstimatedDurationMinutes,
                lesson.Order,
                lesson.IsPublished,
                lesson.UpdatedAtUtc))
            .SingleOrDefaultAsync(cancellationToken);
    }

    public async Task<Guid> CreateModuleAsync(
        EducationModuleWriteRequest request,
        CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var module = new EducationModule
        {
            Id = Guid.NewGuid(),
            Title = request.Title.Trim(),
            Description = request.Description.Trim(),
            Order = request.Order,
            IsPublished = request.IsPublished,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        dbContext.EducationModules.Add(module);
        await dbContext.SaveChangesAsync(cancellationToken);
        return module.Id;
    }

    public async Task<bool> UpdateModuleAsync(
        Guid id,
        EducationModuleWriteRequest request,
        CancellationToken cancellationToken)
    {
        var module = await dbContext.EducationModules.FindAsync([id], cancellationToken);
        if (module is null) return false;

        module.Title = request.Title.Trim();
        module.Description = request.Description.Trim();
        module.Order = request.Order;
        module.IsPublished = request.IsPublished;
        module.UpdatedAtUtc = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<Guid?> CreateLessonAsync(
        Guid moduleId,
        LessonWriteRequest request,
        CancellationToken cancellationToken)
    {
        if (!await dbContext.EducationModules.AnyAsync(
                module => module.Id == moduleId,
                cancellationToken))
        {
            return null;
        }

        var now = DateTimeOffset.UtcNow;
        var lesson = new Lesson
        {
            Id = Guid.NewGuid(),
            EducationModuleId = moduleId,
            Title = request.Title.Trim(),
            Description = request.Description.Trim(),
            Content = request.Content.Trim(),
            EstimatedDurationMinutes = request.EstimatedDurationMinutes,
            Order = request.Order,
            IsPublished = request.IsPublished,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        dbContext.Lessons.Add(lesson);
        await dbContext.SaveChangesAsync(cancellationToken);
        return lesson.Id;
    }

    public async Task<bool> UpdateLessonAsync(
        Guid id,
        LessonWriteRequest request,
        CancellationToken cancellationToken)
    {
        var lesson = await dbContext.Lessons.FindAsync([id], cancellationToken);
        if (lesson is null) return false;

        lesson.Title = request.Title.Trim();
        lesson.Description = request.Description.Trim();
        lesson.Content = request.Content.Trim();
        lesson.EstimatedDurationMinutes = request.EstimatedDurationMinutes;
        lesson.Order = request.Order;
        lesson.IsPublished = request.IsPublished;
        lesson.UpdatedAtUtc = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<Guid?> CreateQuizAsync(
        Guid lessonId,
        QuizWriteRequest request,
        CancellationToken cancellationToken)
    {
        if (!await dbContext.Lessons.AnyAsync(lesson => lesson.Id == lessonId, cancellationToken) ||
            await dbContext.Quizzes.AnyAsync(quiz => quiz.LessonId == lessonId, cancellationToken))
        {
            return null;
        }

        var now = DateTimeOffset.UtcNow;
        var quiz = new Quiz
        {
            Id = Guid.NewGuid(),
            LessonId = lessonId,
            Title = request.Title.Trim(),
            IsPublished = request.IsPublished,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        dbContext.Quizzes.Add(quiz);
        await dbContext.SaveChangesAsync(cancellationToken);
        return quiz.Id;
    }

    public async Task<bool> UpdateQuizAsync(
        Guid id,
        QuizWriteRequest request,
        CancellationToken cancellationToken)
    {
        var quiz = await dbContext.Quizzes.FindAsync([id], cancellationToken);
        if (quiz is null) return false;

        quiz.Title = request.Title.Trim();
        quiz.IsPublished = request.IsPublished;
        quiz.UpdatedAtUtc = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<Guid?> CreateQuestionAsync(
        Guid quizId,
        QuizQuestionWriteRequest request,
        CancellationToken cancellationToken)
    {
        if (!await dbContext.Quizzes.AnyAsync(quiz => quiz.Id == quizId, cancellationToken))
        {
            return null;
        }

        var now = DateTimeOffset.UtcNow;
        var question = new QuizQuestion
        {
            Id = Guid.NewGuid(),
            QuizId = quizId,
            Prompt = request.Prompt.Trim(),
            Order = request.Order,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        dbContext.QuizQuestions.Add(question);
        await dbContext.SaveChangesAsync(cancellationToken);
        return question.Id;
    }

    public async Task<bool> UpdateQuestionAsync(
        Guid id,
        QuizQuestionWriteRequest request,
        CancellationToken cancellationToken)
    {
        var question = await dbContext.QuizQuestions.FindAsync([id], cancellationToken);
        if (question is null) return false;

        question.Prompt = request.Prompt.Trim();
        question.Order = request.Order;
        question.UpdatedAtUtc = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<Guid?> CreateOptionAsync(
        Guid questionId,
        QuizOptionWriteRequest request,
        CancellationToken cancellationToken)
    {
        if (!await dbContext.QuizQuestions.AnyAsync(
                question => question.Id == questionId,
                cancellationToken))
        {
            return null;
        }

        var now = DateTimeOffset.UtcNow;
        var option = new QuizOption
        {
            Id = Guid.NewGuid(),
            QuizQuestionId = questionId,
            Text = request.Text.Trim(),
            IsCorrect = request.IsCorrect,
            Order = request.Order,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };
        dbContext.QuizOptions.Add(option);
        await dbContext.SaveChangesAsync(cancellationToken);
        return option.Id;
    }

    public async Task<bool> UpdateOptionAsync(
        Guid id,
        QuizOptionWriteRequest request,
        CancellationToken cancellationToken)
    {
        var option = await dbContext.QuizOptions.FindAsync([id], cancellationToken);
        if (option is null) return false;

        option.Text = request.Text.Trim();
        option.IsCorrect = request.IsCorrect;
        option.Order = request.Order;
        option.UpdatedAtUtc = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }
}

public sealed record QuizSubmissionOutcome(
    QuizSubmissionStatus Status,
    QuizSubmissionResponse? Response)
{
    public static QuizSubmissionOutcome NotFound { get; } =
        new(QuizSubmissionStatus.NotFound, null);

    public static QuizSubmissionOutcome Invalid { get; } =
        new(QuizSubmissionStatus.Invalid, null);

    public static QuizSubmissionOutcome Success(QuizSubmissionResponse response) =>
        new(QuizSubmissionStatus.Success, response);
}

public enum QuizSubmissionStatus
{
    Success,
    NotFound,
    Invalid,
}
