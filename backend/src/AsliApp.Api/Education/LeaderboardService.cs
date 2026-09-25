using AsliApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AsliApp.Api.Education;

public sealed class LeaderboardService(AppDbContext dbContext, TimeProvider clock)
{
    private sealed class Aggregate
    {
        public Guid UserId { get; init; }
        public int Correct { get; init; }
        public int Questions { get; init; }
        public int QuizCount { get; init; }
    }

    public Task<List<LeaderboardCourseResponse>> GetCoursesAsync(CancellationToken cancellationToken) =>
        dbContext.EducationModules.AsNoTracking()
            .Where(m => m.IsPublished && m.Lessons.Any(l =>
                l.IsPublished && l.Quiz != null && l.Quiz.IsPublished))
            .OrderBy(m => m.Order)
            .Select(m => new LeaderboardCourseResponse(m.Id, m.Title,
                m.Lessons.Count(l => l.IsPublished && l.Quiz != null && l.Quiz.IsPublished)))
            .ToListAsync(cancellationToken);

    public async Task<LeaderboardResponse?> GetAsync(
        Guid userId, string period, Guid? courseId, int offset, int limit,
        CancellationToken cancellationToken)
    {
        string? courseName = null;
        int? courseQuizCount = null;
        if (courseId is not null)
        {
            var course = await dbContext.EducationModules.AsNoTracking()
                .Where(m => m.Id == courseId && m.IsPublished)
                .Select(m => new { m.Title, QuizCount = m.Lessons.Count(l =>
                    l.IsPublished && l.Quiz != null && l.Quiz.IsPublished) })
                .SingleOrDefaultAsync(cancellationToken);
            if (course is null) return null;
            courseName = course.Title;
            courseQuizCount = course.QuizCount;
        }

        var now = clock.GetUtcNow();
        DateTimeOffset? start = period switch
        {
            "weekly" => new DateTimeOffset(now.UtcDateTime.Date.AddDays(
                -((int)now.DayOfWeek + 6) % 7), TimeSpan.Zero),
            "monthly" => new DateTimeOffset(now.Year, now.Month, 1, 0, 0, 0, TimeSpan.Zero),
            _ => null,
        };
        DateTimeOffset? end = period switch
        {
            "weekly" => start!.Value.AddDays(7),
            "monthly" => start!.Value.AddMonths(1),
            _ => null,
        };

        var attempts = dbContext.QuizAttempts.AsNoTracking()
            .Where(a => a.CompletedAtUtc != null && a.TotalQuestionCount > 0);
        if (start is not null)
            attempts = attempts.Where(a => a.CompletedAtUtc >= start && a.CompletedAtUtc < end);
        if (courseId is not null)
            attempts = attempts.Where(a => a.Quiz.Lesson.EducationModuleId == courseId);

        var aggregates = attempts.GroupBy(a => a.UserId).Select(g => new Aggregate
        {
            UserId = g.Key,
            Correct = g.Sum(a => a.CorrectCount),
            Questions = g.Sum(a => a.TotalQuestionCount),
            QuizCount = g.Count(),
        });
        var total = await aggregates.CountAsync(cancellationToken);
        var ordered = aggregates.OrderByDescending(a => a.Correct)
            .ThenByDescending(a => a.QuizCount)
            // Cross multiplication keeps the tie breaker exact without integer division.
            .ThenByDescending(a => (decimal)a.Correct / a.Questions)
            .ThenBy(a => a.UserId.ToString());
        var page = await ordered.Skip(offset).Take(limit)
            .Join(dbContext.Users.AsNoTracking(), a => a.UserId, u => u.Id,
                (a, u) => new { a.UserId, a.Correct, a.Questions, a.QuizCount,
                    u.FirstName, u.LastName })
            .ToListAsync(cancellationToken);

        var entries = page.Select((row, index) => ToEntry(offset + index + 1,
            row.FirstName, row.LastName, row.Correct, row.Questions, row.QuizCount,
            row.UserId == userId)).ToList();

        LeaderboardEntryResponse? current = entries.FirstOrDefault(e => e.IsCurrentUser);
        if (current is null)
        {
            var mine = await aggregates.Where(a => a.UserId == userId)
                .Join(dbContext.Users.AsNoTracking(), a => a.UserId, u => u.Id,
                    (a, u) => new { a.Correct, a.Questions, a.QuizCount,
                        u.FirstName, u.LastName })
                .SingleOrDefaultAsync(cancellationToken);
            if (mine is not null)
            {
                var ahead = await aggregates.CountAsync(a =>
                    a.Correct > mine.Correct ||
                    (a.Correct == mine.Correct && a.QuizCount > mine.QuizCount) ||
                    (a.Correct == mine.Correct && a.QuizCount == mine.QuizCount &&
                        (decimal)a.Correct / a.Questions > (decimal)mine.Correct / mine.Questions) ||
                    (a.Correct == mine.Correct && a.QuizCount == mine.QuizCount &&
                        (decimal)a.Correct / a.Questions == (decimal)mine.Correct / mine.Questions &&
                        string.Compare(a.UserId.ToString(), userId.ToString()) < 0), cancellationToken);
                current = ToEntry(ahead + 1, mine.FirstName, mine.LastName,
                    mine.Correct, mine.Questions, mine.QuizCount, true);
            }
        }
        return new LeaderboardResponse(period, courseId, courseName,
            courseQuizCount, total, offset, limit, entries, current);
    }

    private static LeaderboardEntryResponse ToEntry(int rank, string first, string last,
        int correct, int questions, int quizzes, bool isCurrent) =>
        new(rank, DisplayName(first, last), null, correct, questions, quizzes,
            Math.Round(100m * correct / questions, 0, MidpointRounding.AwayFromZero), isCurrent);

    private static string DisplayName(string first, string last)
    {
        var name = first.Trim();
        var surname = last.Trim();
        if (name.Length == 0) return surname.Length == 0 ? "Katılımcı" : surname;
        return surname.Length == 0 ? name : $"{name} {surname}";
    }
}
