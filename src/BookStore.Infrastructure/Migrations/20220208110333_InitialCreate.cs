using System;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Infrastructure.Migrations
{
    public partial class InitialCreate : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Series",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IntroDuration = table.Column<TimeSpan>(type: "time", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Series", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Seasons",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Number = table.Column<int>(type: "int", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IntroDuration = table.Column<TimeSpan>(type: "time", nullable: false),
                    SeriesId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Seasons", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Seasons_Series_SeriesId",
                        column: x => x.SeriesId,
                        principalTable: "Series",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "DbFile",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Path = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    Name = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Origin = table.Column<int>(type: "int", nullable: false),
                    Duration = table.Column<TimeSpan>(type: "time", nullable: false),
                    Number = table.Column<int>(type: "int", nullable: false),
                    SeasonId = table.Column<int>(type: "int", nullable: false),
                    SeriesId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DbFile", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DbFile_Seasons_SeasonId",
                        column: x => x.SeasonId,
                        principalTable: "Seasons",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DbFile_Series_SeriesId",
                        column: x => x.SeriesId,
                        principalTable: "Series",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "AudioFile",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false),
                    Type = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AudioFile", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AudioFile_DbFile_Id",
                        column: x => x.Id,
                        principalTable: "DbFile",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "VideoFile",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false),
                    Type = table.Column<int>(type: "int", nullable: false),
                    Quality = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VideoFile", x => x.Id);
                    table.ForeignKey(
                        name: "FK_VideoFile_DbFile_Id",
                        column: x => x.Id,
                        principalTable: "DbFile",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "VideoFileExtendedInfos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    VideoFileId = table.Column<int>(type: "int", nullable: false),
                    Cover = table.Column<byte[]>(type: "varbinary(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VideoFileExtendedInfos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_VideoFileExtendedInfos_DbFile_VideoFileId",
                        column: x => x.VideoFileId,
                        principalTable: "DbFile",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

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
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DbFile_SeasonId",
                table: "DbFile",
                column: "SeasonId");

            migrationBuilder.CreateIndex(
                name: "IX_DbFile_SeriesId",
                table: "DbFile",
                column: "SeriesId");

            migrationBuilder.CreateIndex(
                name: "IX_Seasons_SeriesId",
                table: "Seasons",
                column: "SeriesId");

            migrationBuilder.CreateIndex(
                name: "IX_VideoFileExtendedInfos_VideoFileId",
                table: "VideoFileExtendedInfos",
                column: "VideoFileId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VideoFileUserInfos_VideoFileId",
                table: "VideoFileUserInfos",
                column: "VideoFileId",
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AudioFile");

            migrationBuilder.DropTable(
                name: "VideoFile");

            migrationBuilder.DropTable(
                name: "VideoFileExtendedInfos");

            migrationBuilder.DropTable(
                name: "VideoFileUserInfos");

            migrationBuilder.DropTable(
                name: "DbFile");

            migrationBuilder.DropTable(
                name: "Seasons");

            migrationBuilder.DropTable(
                name: "Series");
        }
    }
}
