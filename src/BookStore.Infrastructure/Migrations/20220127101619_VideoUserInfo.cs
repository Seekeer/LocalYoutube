using Microsoft.EntityFrameworkCore.Migrations;

namespace Infrastructure.Migrations
{
    public partial class VideoUserInfo : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Rating",
                table: "VideoFile");

            migrationBuilder.CreateTable(
                name: "VideoFileUserInfos",
                columns: table => new
                {
                    Id = table.Column<int>(nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    VideoFileId = table.Column<int>(nullable: false),
                    Position = table.Column<double>(nullable: false),
                    Rating = table.Column<double>(nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VideoFileUserInfos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_VideoFileUserInfos_VideoFile_VideoFileId",
                        column: x => x.VideoFileId,
                        principalTable: "VideoFile",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_VideoFileUserInfos_VideoFileId",
                table: "VideoFileUserInfos",
                column: "VideoFileId",
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "VideoFileUserInfos");

            migrationBuilder.AddColumn<double>(
                name: "Rating",
                table: "VideoFile",
                type: "float",
                nullable: false,
                defaultValue: 0.0);
        }
    }
}
