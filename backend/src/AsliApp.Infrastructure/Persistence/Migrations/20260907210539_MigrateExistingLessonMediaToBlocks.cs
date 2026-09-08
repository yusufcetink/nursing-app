using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AsliApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class MigrateExistingLessonMediaToBlocks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
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
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

        }
    }
}
