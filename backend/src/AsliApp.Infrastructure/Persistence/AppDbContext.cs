using AsliApp.Domain.Education;
using AsliApp.Domain.Users;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace AsliApp.Infrastructure.Persistence;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options)
    : IdentityDbContext<User, IdentityRole<Guid>, Guid>(options)
{
    public DbSet<EducationModule> EducationModules => Set<EducationModule>();
    public DbSet<Lesson> Lessons => Set<Lesson>();
    public DbSet<LessonMedia> LessonMedia => Set<LessonMedia>();
    public DbSet<LessonContentBlock> LessonContentBlocks => Set<LessonContentBlock>();
    public DbSet<Quiz> Quizzes => Set<Quiz>();
    public DbSet<QuizQuestion> QuizQuestions => Set<QuizQuestion>();
    public DbSet<QuizOption> QuizOptions => Set<QuizOption>();
    public DbSet<QuizAttempt> QuizAttempts => Set<QuizAttempt>();
    public DbSet<QuizAttemptAnswer> QuizAttemptAnswers => Set<QuizAttemptAnswer>();
    public DbSet<LessonProgress> LessonProgress => Set<LessonProgress>();
    public DbSet<EmailVerificationCode> EmailVerificationCodes => Set<EmailVerificationCode>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(entity =>
        {
            entity.Property(user => user.FirstName).HasMaxLength(100).IsRequired();
            entity.Property(user => user.LastName).HasMaxLength(100).IsRequired();
            entity.Property(user => user.Email).HasMaxLength(256).IsRequired();
            entity.HasIndex(user => user.NormalizedEmail)
                .HasDatabaseName("EmailIndex")
                .IsUnique()
                .HasFilter("[NormalizedEmail] IS NOT NULL");
        });

        modelBuilder.Entity<IdentityRole<Guid>>().HasData(
            CreateRole(new Guid("611123a5-51ce-430a-9cf2-768a6a65b379"), UserRole.Student),
            CreateRole(new Guid("46c5ee0a-dff9-4863-9027-a89c64e8e489"), UserRole.ContentEditor),
            CreateRole(new Guid("39269fbd-20fd-4451-9cb0-f21b85a8ce41"), UserRole.Admin));

        modelBuilder.Entity<EmailVerificationCode>(entity =>
        {
            entity.HasKey(code => code.Id);
            entity.Property(code => code.Purpose).HasConversion<string>().HasMaxLength(50);
            entity.Property(code => code.CodeHash).HasMaxLength(512).IsRequired();
            entity.Property(code => code.RowVersion).IsRowVersion();
            entity.HasIndex(code => new { code.UserId, code.Purpose, code.CreatedAtUtc });
            entity.HasIndex(code => new { code.UserId, code.Purpose })
                .IsUnique()
                .HasFilter("[IsUsed] = 0");
            entity.HasOne(code => code.User)
                .WithMany(user => user.EmailVerificationCodes)
                .HasForeignKey(code => code.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<EducationModule>(entity =>
        {
            entity.HasKey(module => module.Id);
            entity.HasQueryFilter(module => !module.IsDeleted);
            entity.Property(module => module.Title).HasMaxLength(200).IsRequired();
            entity.Property(module => module.Description).HasMaxLength(1000).IsRequired();
            entity.HasIndex(module => module.Order);
        });

        modelBuilder.Entity<Lesson>(entity =>
        {
            entity.HasKey(lesson => lesson.Id);
            entity.HasQueryFilter(lesson => !lesson.IsDeleted);
            entity.Property(lesson => lesson.Title).HasMaxLength(200).IsRequired();
            entity.Property(lesson => lesson.Description).HasMaxLength(500).IsRequired();
            entity.HasIndex(lesson => new { lesson.EducationModuleId, lesson.Order });
            entity.HasOne(lesson => lesson.EducationModule)
                .WithMany(module => module.Lessons)
                .HasForeignKey(lesson => lesson.EducationModuleId);
        });

        modelBuilder.Entity<LessonContentBlock>(entity =>
        {
            entity.HasKey(block => block.Id);
            entity.HasQueryFilter(block => !block.Lesson.IsDeleted);
            entity.Property(block => block.BlockType).HasConversion<string>().HasMaxLength(20);
            entity.Property(block => block.TextContent);
            entity.HasIndex(block => new { block.LessonId, block.SortOrder }).IsUnique();
            entity.HasOne(block => block.Lesson)
                .WithMany(lesson => lesson.ContentBlocks)
                .HasForeignKey(block => block.LessonId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(block => block.Media)
                .WithMany(media => media.ContentBlocks)
                .HasForeignKey(block => block.MediaId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<LessonMedia>(entity =>
        {
            entity.ToTable("LessonMedia");
            entity.HasKey(media => media.Id);
            entity.HasQueryFilter(media => !media.Lesson.IsDeleted);
            entity.Property(media => media.OriginalFileName)
                .HasMaxLength(255)
                .IsRequired();
            entity.Property(media => media.StorageKey)
                .HasMaxLength(500)
                .IsRequired();
            entity.Property(media => media.ContentType)
                .HasMaxLength(100)
                .IsRequired();
            entity.Property(media => media.MediaType).HasConversion<string>().HasMaxLength(20);
            entity.HasIndex(media => media.StorageKey).IsUnique();
            entity.HasIndex(media => new { media.LessonId, media.SortOrder });
            entity.HasOne(media => media.Lesson)
                .WithMany(lesson => lesson.Media)
                .HasForeignKey(media => media.LessonId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Quiz>(entity =>
        {
            entity.HasKey(quiz => quiz.Id);
            entity.HasQueryFilter(quiz => !quiz.IsDeleted);
            entity.Property(quiz => quiz.Title).HasMaxLength(200).IsRequired();
            entity.HasIndex(quiz => quiz.LessonId)
                .IsUnique()
                .HasFilter("[IsDeleted] = 0");
            entity.HasOne(quiz => quiz.Lesson)
                .WithOne(lesson => lesson.Quiz)
                .HasForeignKey<Quiz>(quiz => quiz.LessonId);
        });

        modelBuilder.Entity<QuizQuestion>(entity =>
        {
            entity.HasKey(question => question.Id);
            entity.HasQueryFilter(question => !question.IsDeleted);
            entity.Property(question => question.Prompt).HasMaxLength(1000).IsRequired();
            entity.HasIndex(question => new { question.QuizId, question.Order })
                .IsUnique()
                .HasFilter("[IsDeleted] = 0");
            entity.HasOne(question => question.Quiz)
                .WithMany(quiz => quiz.Questions)
                .HasForeignKey(question => question.QuizId);
        });

        modelBuilder.Entity<QuizOption>(entity =>
        {
            entity.HasKey(option => option.Id);
            entity.HasQueryFilter(option => !option.QuizQuestion.IsDeleted);
            entity.Property(option => option.Text).HasMaxLength(500).IsRequired();
            entity.HasIndex(option => new { option.QuizQuestionId, option.Order }).IsUnique();
            entity.HasOne(option => option.QuizQuestion)
                .WithMany(question => question.Options)
                .HasForeignKey(option => option.QuizQuestionId);
        });

        modelBuilder.Entity<QuizAttempt>(entity =>
        {
            entity.HasKey(attempt => attempt.Id);
            entity.HasQueryFilter(attempt => !attempt.Quiz.IsDeleted);
            entity.Property(attempt => attempt.ScorePercentage).HasPrecision(5, 2);
            entity.HasIndex(attempt => new { attempt.UserId, attempt.CompletedAtUtc });
            entity.HasOne(attempt => attempt.User)
                .WithMany(user => user.QuizAttempts)
                .HasForeignKey(attempt => attempt.UserId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(attempt => attempt.Quiz)
                .WithMany(quiz => quiz.Attempts)
                .HasForeignKey(attempt => attempt.QuizId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<QuizAttemptAnswer>(entity =>
        {
            entity.HasKey(answer => answer.Id);
            entity.HasQueryFilter(answer =>
                !answer.QuizAttempt.Quiz.IsDeleted &&
                !answer.QuizQuestion.IsDeleted);
            entity.HasIndex(answer => new { answer.QuizAttemptId, answer.QuizQuestionId })
                .IsUnique();
            entity.HasOne(answer => answer.QuizAttempt)
                .WithMany(attempt => attempt.Answers)
                .HasForeignKey(answer => answer.QuizAttemptId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(answer => answer.QuizQuestion)
                .WithMany()
                .HasForeignKey(answer => answer.QuizQuestionId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(answer => answer.SelectedOption)
                .WithMany()
                .HasForeignKey(answer => answer.SelectedOptionId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<LessonProgress>(entity =>
        {
            entity.HasKey(progress => progress.Id);
            entity.HasQueryFilter(progress => !progress.Lesson.IsDeleted);
            entity.HasIndex(progress => new { progress.UserId, progress.LessonId }).IsUnique();
            entity.HasOne(progress => progress.User)
                .WithMany(user => user.LessonProgress)
                .HasForeignKey(progress => progress.UserId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(progress => progress.Lesson)
                .WithMany(lesson => lesson.ProgressEntries)
                .HasForeignKey(progress => progress.LessonId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }

    private static IdentityRole<Guid> CreateRole(Guid id, UserRole role)
    {
        var name = role.ToString();
        return new IdentityRole<Guid>
        {
            Id = id,
            Name = name,
            NormalizedName = name.ToUpperInvariant(),
            ConcurrencyStamp = id.ToString(),
        };
    }
}
