using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AsliApp.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class CompletePushNotifications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_UserDevices_FcmToken",
                table: "UserDevices");

            migrationBuilder.RenameColumn(
                name: "LastSeenAtUtc",
                table: "UserDevices",
                newName: "LastUpdatedAtUtc");

            migrationBuilder.RenameColumn(
                name: "FcmToken",
                table: "UserDevices",
                newName: "DeviceToken");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "OpenedAtUtc",
                table: "PushNotificationLogs",
                type: "datetimeoffset",
                nullable: true);

            migrationBuilder.Sql(
                """
                WITH DuplicateTokens AS
                (
                    SELECT [Id], ROW_NUMBER() OVER (
                        PARTITION BY [DeviceToken]
                        ORDER BY [LastUpdatedAtUtc] DESC, [Id] DESC) AS [RowNumber]
                    FROM [UserDevices]
                    WHERE [DeviceToken] <> N''
                )
                UPDATE [UserDevices]
                SET [DeviceToken] = N'', [IsActive] = 0, [NotificationsEnabled] = 0
                WHERE [Id] IN (SELECT [Id] FROM DuplicateTokens WHERE [RowNumber] > 1);
                """);

            migrationBuilder.CreateIndex(
                name: "IX_UserDevices_DeviceToken",
                table: "UserDevices",
                column: "DeviceToken",
                unique: true,
                filter: "[DeviceToken] <> N''");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_UserDevices_DeviceToken",
                table: "UserDevices");

            migrationBuilder.DropColumn(
                name: "OpenedAtUtc",
                table: "PushNotificationLogs");

            migrationBuilder.RenameColumn(
                name: "LastUpdatedAtUtc",
                table: "UserDevices",
                newName: "LastSeenAtUtc");

            migrationBuilder.RenameColumn(
                name: "DeviceToken",
                table: "UserDevices",
                newName: "FcmToken");

            migrationBuilder.CreateIndex(
                name: "IX_UserDevices_FcmToken",
                table: "UserDevices",
                column: "FcmToken");
        }
    }
}
