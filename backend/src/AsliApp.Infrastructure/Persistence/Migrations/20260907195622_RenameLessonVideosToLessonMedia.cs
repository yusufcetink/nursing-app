using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AsliApp.Infrastructure.Persistence.Migrations
{
    public partial class RenameLessonVideosToLessonMedia : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_LessonVideos_Lessons_LessonId",
                table: "LessonVideos");
            migrationBuilder.DropPrimaryKey(
                name: "PK_LessonVideos",
                table: "LessonVideos");
            migrationBuilder.RenameTable(
                name: "LessonVideos",
                newName: "LessonMedia");
            migrationBuilder.RenameIndex(
                name: "IX_LessonVideos_StorageKey",
                table: "LessonMedia",
                newName: "IX_LessonMedia_StorageKey");
            migrationBuilder.RenameIndex(
                name: "IX_LessonVideos_LessonId_SortOrder",
                table: "LessonMedia",
                newName: "IX_LessonMedia_LessonId_SortOrder");
            migrationBuilder.AddPrimaryKey(
                name: "PK_LessonMedia",
                table: "LessonMedia",
                column: "Id");
            migrationBuilder.AddForeignKey(
                name: "FK_LessonMedia_Lessons_LessonId",
                table: "LessonMedia",
                column: "LessonId",
                principalTable: "Lessons",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_LessonMedia_Lessons_LessonId",
                table: "LessonMedia");
            migrationBuilder.DropPrimaryKey(
                name: "PK_LessonMedia",
                table: "LessonMedia");
            migrationBuilder.RenameTable(
                name: "LessonMedia",
                newName: "LessonVideos");
            migrationBuilder.RenameIndex(
                name: "IX_LessonMedia_StorageKey",
                table: "LessonVideos",
                newName: "IX_LessonVideos_StorageKey");
            migrationBuilder.RenameIndex(
                name: "IX_LessonMedia_LessonId_SortOrder",
                table: "LessonVideos",
                newName: "IX_LessonVideos_LessonId_SortOrder");
            migrationBuilder.AddPrimaryKey(
                name: "PK_LessonVideos",
                table: "LessonVideos",
                column: "Id");
            migrationBuilder.AddForeignKey(
                name: "FK_LessonVideos_Lessons_LessonId",
                table: "LessonVideos",
                column: "LessonId",
                principalTable: "Lessons",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
