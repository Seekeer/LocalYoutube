using Microsoft.EntityFrameworkCore.Migrations;

namespace Infrastructure.Migrations
{
    public partial class InitialCreate4 : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "RutrackerUrl",
                table: "VideoFileExtendedInfos",
                newName: "Description");

            migrationBuilder.AddColumn<int>(
                name: "RutrackerId",
                table: "VideoFileExtendedInfos",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RutrackerId",
                table: "VideoFileExtendedInfos");

            migrationBuilder.RenameColumn(
                name: "Description",
                table: "VideoFileExtendedInfos",
                newName: "RutrackerUrl");
        }
    }
}
