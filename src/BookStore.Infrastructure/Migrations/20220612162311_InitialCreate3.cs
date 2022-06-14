using Microsoft.EntityFrameworkCore.Migrations;

namespace Infrastructure.Migrations
{
    public partial class InitialCreate3 : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Genres",
                table: "VideoFileExtendedInfos",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RutrackerUrl",
                table: "VideoFileExtendedInfos",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Year",
                table: "VideoFileExtendedInfos",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<bool>(
                name: "IsDownloading",
                table: "VideoFile",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Genres",
                table: "VideoFileExtendedInfos");

            migrationBuilder.DropColumn(
                name: "RutrackerUrl",
                table: "VideoFileExtendedInfos");

            migrationBuilder.DropColumn(
                name: "Year",
                table: "VideoFileExtendedInfos");

            migrationBuilder.DropColumn(
                name: "IsDownloading",
                table: "VideoFile");
        }
    }
}
