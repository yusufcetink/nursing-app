using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AsliApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SupportMultipleQuizzesPerLesson : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Quizzes_LessonId",
                table: "Quizzes");

            migrationBuilder.AddColumn<int>(
                name: "Order",
                table: "Quizzes",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "IX_Quizzes_LessonId",
                table: "Quizzes",
                column: "LessonId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Quizzes_LessonId",
                table: "Quizzes");

            migrationBuilder.DropColumn(
                name: "Order",
                table: "Quizzes");

            migrationBuilder.CreateIndex(
                name: "IX_Quizzes_LessonId",
                table: "Quizzes",
                column: "LessonId",
                unique: true,
                filter: "[IsDeleted] = 0");
        }
    }
}
