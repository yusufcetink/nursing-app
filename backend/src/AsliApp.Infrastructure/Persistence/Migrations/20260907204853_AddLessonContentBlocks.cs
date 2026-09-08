using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AsliApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddLessonContentBlocks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "LessonContentBlocks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LessonId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    BlockType = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    TextContent = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    MediaId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    SortOrder = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LessonContentBlocks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LessonContentBlocks_LessonMedia_MediaId",
                        column: x => x.MediaId,
                        principalTable: "LessonMedia",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_LessonContentBlocks_Lessons_LessonId",
                        column: x => x.LessonId,
                        principalTable: "Lessons",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_LessonContentBlocks_LessonId_SortOrder",
                table: "LessonContentBlocks",
                columns: new[] { "LessonId", "SortOrder" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_LessonContentBlocks_MediaId",
                table: "LessonContentBlocks",
                column: "MediaId");

            migrationBuilder.Sql(
                """
                INSERT INTO [LessonContentBlocks]
                    ([Id], [LessonId], [BlockType], [TextContent], [MediaId], [SortOrder])
                SELECT NEWID(), [Id], N'Text', [Content], NULL, 0
                FROM [Lessons]
                WHERE NULLIF(LTRIM(RTRIM([Content])), N'') IS NOT NULL;
                """);

            migrationBuilder.Sql(
                """
                ;WITH [MissingMedia] AS (
                    SELECT [m].[Id], [m].[LessonId], [m].[MediaType],
                        ROW_NUMBER() OVER (
                            PARTITION BY [m].[LessonId]
                            ORDER BY [m].[SortOrder], [m].[OriginalFileName], [m].[Id]) - 1 AS [MediaOrder]
                    FROM [LessonMedia] AS [m]
                    WHERE NOT EXISTS (
                        SELECT 1 FROM [LessonContentBlocks] AS [b]
                        WHERE [b].[MediaId] = [m].[Id])
                )
                INSERT INTO [LessonContentBlocks]
                    ([Id], [LessonId], [BlockType], [TextContent], [MediaId], [SortOrder])
                SELECT NEWID(), [m].[LessonId], [m].[MediaType], NULL, [m].[Id],
                    COALESCE((
                        SELECT MAX([b].[SortOrder]) + 1
                        FROM [LessonContentBlocks] AS [b]
                        WHERE [b].[LessonId] = [m].[LessonId]
                    ), 0) + [m].[MediaOrder]
                FROM [MissingMedia] AS [m];
                """);

            migrationBuilder.DropColumn(
                name: "Content",
                table: "Lessons");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Content",
                table: "Lessons",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.Sql(
                """
                UPDATE [Lessons]
                SET [Content] = COALESCE((
                    SELECT TOP(1) [TextContent]
                    FROM [LessonContentBlocks]
                    WHERE [LessonId] = [Lessons].[Id]
                        AND [BlockType] = N'Text'
                    ORDER BY [SortOrder]
                ), N'');
                """);

            migrationBuilder.DropTable(
                name: "LessonContentBlocks");
        }
    }
}
