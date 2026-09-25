using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AsliApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class QuizAttemptResume : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "CompletedAtUtc",
                table: "QuizAttempts",
                type: "datetimeoffset",
                nullable: true,
                oldClrType: typeof(DateTimeOffset),
                oldType: "datetimeoffset");

            migrationBuilder.AddColumn<bool>(
                name: "IsArchived",
                table: "QuizAttempts",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "SnapshotJson",
                table: "QuizAttempts",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "StartedAtUtc",
                table: "QuizAttempts",
                type: "datetimeoffset",
                nullable: false,
                defaultValue: new DateTimeOffset(new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)));

            migrationBuilder.AddColumn<int>(
                name: "Version",
                table: "QuizAttempts",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Keep historical results and answers; only the latest existing result
            // occupies the single student attempt slot after upgrading.
            migrationBuilder.Sql("""
                UPDATE [QuizAttempts] SET [StartedAtUtc] = [CompletedAtUtc]
                WHERE [CompletedAtUtc] IS NOT NULL;
                WITH ranked AS (
                    SELECT [IsArchived], ROW_NUMBER() OVER (
                        PARTITION BY [UserId], [QuizId]
                        ORDER BY [CompletedAtUtc] DESC, [Id] DESC) AS rn
                    FROM [QuizAttempts]
                )
                UPDATE ranked SET [IsArchived] = 1 WHERE rn > 1;
                """);

            migrationBuilder.CreateIndex(
                name: "IX_QuizAttempts_UserId_QuizId",
                table: "QuizAttempts",
                columns: new[] { "UserId", "QuizId" },
                unique: true,
                filter: "[IsArchived] = 0");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_QuizAttempts_UserId_QuizId",
                table: "QuizAttempts");

            migrationBuilder.DropColumn(
                name: "IsArchived",
                table: "QuizAttempts");

            migrationBuilder.DropColumn(
                name: "SnapshotJson",
                table: "QuizAttempts");

            migrationBuilder.DropColumn(
                name: "StartedAtUtc",
                table: "QuizAttempts");

            migrationBuilder.DropColumn(
                name: "Version",
                table: "QuizAttempts");

            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "CompletedAtUtc",
                table: "QuizAttempts",
                type: "datetimeoffset",
                nullable: false,
                defaultValue: new DateTimeOffset(new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)),
                oldClrType: typeof(DateTimeOffset),
                oldType: "datetimeoffset",
                oldNullable: true);
        }
    }
}
