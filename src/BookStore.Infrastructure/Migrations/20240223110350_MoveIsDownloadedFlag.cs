using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class MoveIsDownloadedFlag : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsDownloading",
                table: "VideoFile");

            migrationBuilder.AddColumn<bool>(
                name: "IsDownloading",
                table: "DbFile",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsDownloading",
                table: "DbFile");

            migrationBuilder.AddColumn<bool>(
                name: "IsDownloading",
                table: "VideoFile",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }
    }
}
