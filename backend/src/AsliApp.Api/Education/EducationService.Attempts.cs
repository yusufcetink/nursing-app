using System.Text.Json;
using AsliApp.Domain.Education;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace AsliApp.Api.Education;

public sealed record QuizAttemptResponse(
    Guid? AttemptId,
    string Status,
    StudentQuizResponse Quiz,
    IReadOnlyList<QuizAnswerRequest> Answers,
    int AnsweredCount,
    QuizSubmissionResponse? Result);

public sealed record QuizAttemptOutcome(int StatusCode, QuizAttemptResponse? Response = null);

public sealed partial class EducationService
{
    // Kept private: the answer key is persisted but never returned by student endpoints.
    private sealed record AttemptSnapshot(StudentQuizResponse Quiz, Dictionary<Guid, Guid> AnswerKey);

    public async Task<QuizAttemptOutcome> GetQuizAttemptAsync(
        Guid userId, Guid quizId, bool start, CancellationToken cancellationToken)
    {
        var quiz = await dbContext.Quizzes
            .Include(q => q.Questions.Where(q => !q.IsDeleted)).ThenInclude(q => q.Options)
            .SingleOrDefaultAsync(q => q.Id == quizId &&
                q.Lesson.IsPublished && q.Lesson.EducationModule.IsPublished &&
                !q.Lesson.IsDeleted && !q.Lesson.EducationModule.IsDeleted, cancellationToken);
        if (quiz is null) return new(404);
        var attempt = await dbContext.QuizAttempts.Include(a => a.Answers)
            .SingleOrDefaultAsync(a => a.UserId == userId && a.QuizId == quiz.Id, cancellationToken);
        if (attempt is not null) return new(200, ToAttemptResponse(attempt, ToStudentQuiz(quiz)));
        if (!quiz.IsPublished) return new(404);
        var studentQuiz = ToStudentQuiz(quiz);
        if (!start) return new(200, new(null, "NotStarted", studentQuiz, [], 0, null));
        // Existing attempts above remain resumable, including attempts from before this prerequisite.
        if (!await dbContext.LessonProgress.AnyAsync(p =>
                p.UserId == userId && p.LessonId == quiz.LessonId && p.IsCompleted,
                cancellationToken)) return new(403);
        if (quiz.Questions.Count == 0 || quiz.Questions.Any(q =>
            q.Options.Count != 4 || q.Options.Count(o => o.IsCorrect) != 1)) return new(409);
        attempt = new QuizAttempt
        {
            Id = Guid.NewGuid(), UserId = userId, QuizId = quiz.Id,
            StartedAtUtc = DateTimeOffset.UtcNow, TotalQuestionCount = quiz.Questions.Count,
            SnapshotJson = JsonSerializer.Serialize(new AttemptSnapshot(studentQuiz,
                quiz.Questions.ToDictionary(q => q.Id, q => q.Options.Single(o => o.IsCorrect).Id))),
        };
        dbContext.QuizAttempts.Add(attempt);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException error) when (error.InnerException is SqlException { Number: 2601 or 2627 })
        {
            // Another request won the unique (UserId, QuizId) insert.
            dbContext.ChangeTracker.Clear();
            attempt = await dbContext.QuizAttempts.Include(a => a.Answers)
                .SingleAsync(a => a.UserId == userId && a.QuizId == quiz.Id, cancellationToken);
        }
        return new(200, ToAttemptResponse(attempt, studentQuiz));
    }

    public async Task<QuizAttemptOutcome> SaveQuizAnswerAsync(
        Guid userId, Guid attemptId, QuizAnswerRequest request, CancellationToken cancellationToken)
    {
        for (var retry = 0; retry < 3; retry++)
        {
            var attempt = await dbContext.QuizAttempts.Include(a => a.Answers)
                .SingleOrDefaultAsync(a => a.Id == attemptId && a.UserId == userId &&
                    a.Quiz.Lesson.IsPublished && !a.Quiz.Lesson.IsDeleted &&
                    a.Quiz.Lesson.EducationModule.IsPublished && !a.Quiz.Lesson.EducationModule.IsDeleted,
                    cancellationToken);
            if (attempt is null) return new(404);
            if (string.IsNullOrEmpty(attempt.SnapshotJson)) return new(409); // historical completed result
            var snapshot = JsonSerializer.Deserialize<AttemptSnapshot>(attempt.SnapshotJson)!;
            var existing = attempt.Answers.SingleOrDefault(a => a.QuizQuestionId == request.QuestionId);
            if (existing is not null)
                return existing.SelectedOptionId == request.SelectedOptionId
                    ? new(200, ToAttemptResponse(attempt, snapshot.Quiz)) : new(409);
            if (attempt.CompletedAtUtc is not null) return new(409);
            var next = snapshot.Quiz.Questions.FirstOrDefault(q => !attempt.Answers.Any(a => a.QuizQuestionId == q.Id));
            if (next is null || next.Id != request.QuestionId ||
                !next.Options.Any(o => o.Id == request.SelectedOptionId)) return new(400);
            var correct = snapshot.AnswerKey[request.QuestionId] == request.SelectedOptionId;
            var savedAnswer = new QuizAttemptAnswer
            {
                Id = Guid.NewGuid(), QuizQuestionId = request.QuestionId,
                SelectedOptionId = request.SelectedOptionId, IsCorrect = correct,
                QuizAttemptId = attempt.Id,
            };
            dbContext.QuizAttemptAnswers.Add(savedAnswer);
            attempt.Version++;
            if (attempt.Answers.Count == attempt.TotalQuestionCount)
            {
                attempt.CorrectCount = attempt.Answers.Count(a => a.IsCorrect);
                attempt.IncorrectCount = attempt.TotalQuestionCount - attempt.CorrectCount;
                attempt.ScorePercentage = Math.Round(100m * attempt.CorrectCount / attempt.TotalQuestionCount,
                    2, MidpointRounding.AwayFromZero);
                attempt.CompletedAtUtc = DateTimeOffset.UtcNow;
            }
            try
            {
                // EF's transaction commits the answer and version/result atomically.
                await dbContext.SaveChangesAsync(cancellationToken);
                return new(200, ToAttemptResponse(attempt, snapshot.Quiz));
            }
            catch (DbUpdateConcurrencyException)
            {
                dbContext.ChangeTracker.Clear();
            }
            catch (DbUpdateException error) when (error.InnerException is SqlException { Number: 2601 or 2627 })
            {
                dbContext.ChangeTracker.Clear();
            }
        }
        return new(409);
    }

    public async Task ResetQuizAttemptAsync(Guid userId, Guid quizId, CancellationToken cancellationToken)
    {
        var attempts = await dbContext.QuizAttempts.IgnoreQueryFilters().Include(a => a.Answers)
            .Where(a => a.UserId == userId && a.QuizId == quizId).ToListAsync(cancellationToken);
        var progress = await dbContext.LessonProgress.IgnoreQueryFilters()
            .Where(p => p.UserId == userId && dbContext.Quizzes.IgnoreQueryFilters()
                .Any(q => q.Id == quizId && q.LessonId == p.LessonId)).ToListAsync(cancellationToken);
        dbContext.QuizAttempts.RemoveRange(attempts);
        dbContext.LessonProgress.RemoveRange(progress);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static StudentQuizResponse ToStudentQuiz(Quiz quiz) => new(
        quiz.Id, quiz.LessonId, quiz.Title,
        quiz.Questions.OrderBy(q => q.Order).ThenBy(q => q.Id).Select(q =>
            new StudentQuizQuestionResponse(q.Id, q.Prompt, q.Order,
                q.Options.OrderBy(o => o.Order).Select(o => new StudentQuizOptionResponse(o.Id, o.Text, o.Order)).ToList())).ToList(),
        quiz.UpdatedAtUtc);

    private static QuizAttemptResponse ToAttemptResponse(QuizAttempt attempt, StudentQuizResponse fallback)
    {
        var quiz = string.IsNullOrEmpty(attempt.SnapshotJson) ? fallback
            : JsonSerializer.Deserialize<AttemptSnapshot>(attempt.SnapshotJson)!.Quiz;
        var answers = attempt.Answers.Select(a => new QuizAnswerRequest(a.QuizQuestionId, a.SelectedOptionId)).ToList();
        return new(attempt.Id, attempt.CompletedAtUtc is null ? "InProgress" : "Completed", quiz,
            answers, answers.Count, attempt.CompletedAtUtc is null ? null : new QuizSubmissionResponse(
                attempt.Id, attempt.QuizId, attempt.TotalQuestionCount, attempt.CorrectCount,
                attempt.IncorrectCount, attempt.ScorePercentage, attempt.CompletedAtUtc.Value));
    }
}
