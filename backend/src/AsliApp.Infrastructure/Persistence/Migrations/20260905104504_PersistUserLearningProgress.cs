using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AsliApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class PersistUserLearningProgress : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "TotalQuestionCount",
                table: "QuizAttempts",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "QuizAttemptAnswers",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    QuizAttemptId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    QuizQuestionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SelectedOptionId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    IsCorrect = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_QuizAttemptAnswers", x => x.Id);
                    table.ForeignKey(
                        name: "FK_QuizAttemptAnswers_QuizAttempts_QuizAttemptId",
                        column: x => x.QuizAttemptId,
                        principalTable: "QuizAttempts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_QuizAttemptAnswers_QuizOptions_SelectedOptionId",
                        column: x => x.SelectedOptionId,
                        principalTable: "QuizOptions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_QuizAttemptAnswers_QuizQuestions_QuizQuestionId",
                        column: x => x.QuizQuestionId,
                        principalTable: "QuizQuestions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_QuizAttemptAnswers_QuizAttemptId_QuizQuestionId",
                table: "QuizAttemptAnswers",
                columns: new[] { "QuizAttemptId", "QuizQuestionId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_QuizAttemptAnswers_QuizQuestionId",
                table: "QuizAttemptAnswers",
                column: "QuizQuestionId");

            migrationBuilder.CreateIndex(
                name: "IX_QuizAttemptAnswers_SelectedOptionId",
                table: "QuizAttemptAnswers",
                column: "SelectedOptionId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "QuizAttemptAnswers");

            migrationBuilder.DropColumn(
                name: "TotalQuestionCount",
                table: "QuizAttempts");
        }
    }
}
