using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate10 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "VideoFileUserInfos");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "VideoFileUserInfos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    VideoFileId = table.Column<int>(type: "int", nullable: false),
                    Position = table.Column<double>(type: "float", nullable: false),
                    Rating = table.Column<double>(type: "float", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VideoFileUserInfos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_VideoFileUserInfos_DbFile_VideoFileId",
                        column: x => x.VideoFileId,
                        principalTable: "DbFile",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_VideoFileUserInfos_VideoFileId",
                table: "VideoFileUserInfos",
                column: "VideoFileId",
                unique: true);
        }
    }
}
