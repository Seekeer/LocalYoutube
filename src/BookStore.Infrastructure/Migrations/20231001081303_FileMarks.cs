using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class FileMarks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "FileMarks",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DbFileId = table.Column<int>(type: "int", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    Position = table.Column<double>(type: "float", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FileMarks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_FileMarks_DbFile_DbFileId",
                        column: x => x.DbFileId,
                        principalTable: "DbFile",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_FileMarks_DbFileId",
                table: "FileMarks",
                column: "DbFileId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "FileMarks");
        }
    }
}
