using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.MigrationsSqlite
{
    /// <inheritdoc />
    public partial class BigUpdate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_AudioFile_DbFile_Id",
                table: "AudioFile");

            migrationBuilder.DropForeignKey(
                name: "FK_DbFile_Seasons_SeasonId",
                table: "DbFile");

            migrationBuilder.DropForeignKey(
                name: "FK_DbFile_Series_SeriesId",
                table: "DbFile");

            migrationBuilder.DropForeignKey(
                name: "FK_FileMarks_DbFile_DbFileId",
                table: "FileMarks");

            migrationBuilder.DropForeignKey(
                name: "FK_Seasons_Series_SeriesId",
                table: "Seasons");

            migrationBuilder.DropForeignKey(
                name: "FK_VideoFile_DbFile_Id",
                table: "VideoFile");

            migrationBuilder.DropForeignKey(
                name: "FK_VideoFileExtendedInfos_DbFile_VideoFileId",
                table: "VideoFileExtendedInfos");

            migrationBuilder.DropForeignKey(
                name: "FK_VideoFileUserInfos_AspNetUsers_UserId",
                table: "VideoFileUserInfos");

            migrationBuilder.DropForeignKey(
                name: "FK_VideoFileUserInfos_DbFile_VideoFileId",
                table: "VideoFileUserInfos");

            migrationBuilder.DropColumn(
                name: "Cover",
                table: "VideoFileExtendedInfos");

            migrationBuilder.AddColumn<bool>(
                name: "SkipFile",
                table: "VideoFileUserInfos",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "ExternalVideoSource",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    ChannelId = table.Column<string>(type: "TEXT", nullable: true),
                    ChannelName = table.Column<string>(type: "TEXT", nullable: true),
                    PlaylistId = table.Column<string>(type: "TEXT", nullable: true),
                    CheckNewVideo = table.Column<bool>(type: "INTEGER", nullable: false),
                    SeriesId = table.Column<int>(type: "INTEGER", nullable: false),
                    SeasonId = table.Column<int>(type: "INTEGER", nullable: false),
                    Network = table.Column<int>(type: "INTEGER", nullable: false),
                    LastCheckDate = table.Column<DateTime>(type: "TEXT", nullable: false),
                    UpdatedDate = table.Column<DateTime>(type: "TEXT", nullable: false),
                    CreatedDate = table.Column<DateTime>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ExternalVideoSource", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Playlists",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Name = table.Column<string>(type: "TEXT", nullable: true),
                    UpdatedDate = table.Column<DateTime>(type: "TEXT", nullable: false),
                    CreatedDate = table.Column<DateTime>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Playlists", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "VideoFileCoverInfo",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    VideoFileId = table.Column<int>(type: "INTEGER", nullable: false),
                    Cover = table.Column<byte[]>(type: "BLOB", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VideoFileCoverInfo", x => x.Id);
                    table.ForeignKey(
                        name: "FK_VideoFileCoverInfo_DbFile_VideoFileId",
                        column: x => x.VideoFileId,
                        principalTable: "DbFile",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlaylistItems",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    FileId = table.Column<int>(type: "INTEGER", nullable: true),
                    Index = table.Column<int>(type: "INTEGER", nullable: false),
                    PlaylistId = table.Column<int>(type: "INTEGER", nullable: true),
                    UpdatedDate = table.Column<DateTime>(type: "TEXT", nullable: false),
                    CreatedDate = table.Column<DateTime>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlaylistItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlaylistItems_DbFile_FileId",
                        column: x => x.FileId,
                        principalTable: "DbFile",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PlaylistItems_Playlists_PlaylistId",
                        column: x => x.PlaylistId,
                        principalTable: "Playlists",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PlaylistItems_FileId",
                table: "PlaylistItems",
                column: "FileId");

            migrationBuilder.CreateIndex(
                name: "IX_PlaylistItems_PlaylistId",
                table: "PlaylistItems",
                column: "PlaylistId");

            migrationBuilder.CreateIndex(
                name: "IX_VideoFileCoverInfo_VideoFileId",
                table: "VideoFileCoverInfo",
                column: "VideoFileId",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_AudioFile_DbFile_Id",
                table: "AudioFile",
                column: "Id",
                principalTable: "DbFile",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_DbFile_Seasons_SeasonId",
                table: "DbFile",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_DbFile_Series_SeriesId",
                table: "DbFile",
                column: "SeriesId",
                principalTable: "Series",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_FileMarks_DbFile_DbFileId",
                table: "FileMarks",
                column: "DbFileId",
                principalTable: "DbFile",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Seasons_Series_SeriesId",
                table: "Seasons",
                column: "SeriesId",
                principalTable: "Series",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_VideoFile_DbFile_Id",
                table: "VideoFile",
                column: "Id",
                principalTable: "DbFile",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_VideoFileExtendedInfos_DbFile_VideoFileId",
                table: "VideoFileExtendedInfos",
                column: "VideoFileId",
                principalTable: "DbFile",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_VideoFileUserInfos_AspNetUsers_UserId",
                table: "VideoFileUserInfos",
                column: "UserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_VideoFileUserInfos_DbFile_VideoFileId",
                table: "VideoFileUserInfos",
                column: "VideoFileId",
                principalTable: "DbFile",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_AudioFile_DbFile_Id",
                table: "AudioFile");

            migrationBuilder.DropForeignKey(
                name: "FK_DbFile_Seasons_SeasonId",
                table: "DbFile");

            migrationBuilder.DropForeignKey(
                name: "FK_DbFile_Series_SeriesId",
                table: "DbFile");

            migrationBuilder.DropForeignKey(
                name: "FK_FileMarks_DbFile_DbFileId",
                table: "FileMarks");

            migrationBuilder.DropForeignKey(
                name: "FK_Seasons_Series_SeriesId",
                table: "Seasons");

            migrationBuilder.DropForeignKey(
                name: "FK_VideoFile_DbFile_Id",
                table: "VideoFile");

            migrationBuilder.DropForeignKey(
                name: "FK_VideoFileExtendedInfos_DbFile_VideoFileId",
                table: "VideoFileExtendedInfos");

            migrationBuilder.DropForeignKey(
                name: "FK_VideoFileUserInfos_AspNetUsers_UserId",
                table: "VideoFileUserInfos");

            migrationBuilder.DropForeignKey(
                name: "FK_VideoFileUserInfos_DbFile_VideoFileId",
                table: "VideoFileUserInfos");

            migrationBuilder.DropTable(
                name: "ExternalVideoSource");

            migrationBuilder.DropTable(
                name: "PlaylistItems");

            migrationBuilder.DropTable(
                name: "VideoFileCoverInfo");

            migrationBuilder.DropTable(
                name: "Playlists");

            migrationBuilder.DropColumn(
                name: "SkipFile",
                table: "VideoFileUserInfos");

            migrationBuilder.AddColumn<byte[]>(
                name: "Cover",
                table: "VideoFileExtendedInfos",
                type: "BLOB",
                nullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_AudioFile_DbFile_Id",
                table: "AudioFile",
                column: "Id",
                principalTable: "DbFile",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_DbFile_Seasons_SeasonId",
                table: "DbFile",
                column: "SeasonId",
                principalTable: "Seasons",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_DbFile_Series_SeriesId",
                table: "DbFile",
                column: "SeriesId",
                principalTable: "Series",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_FileMarks_DbFile_DbFileId",
                table: "FileMarks",
                column: "DbFileId",
                principalTable: "DbFile",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Seasons_Series_SeriesId",
                table: "Seasons",
                column: "SeriesId",
                principalTable: "Series",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_VideoFile_DbFile_Id",
                table: "VideoFile",
                column: "Id",
                principalTable: "DbFile",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_VideoFileExtendedInfos_DbFile_VideoFileId",
                table: "VideoFileExtendedInfos",
                column: "VideoFileId",
                principalTable: "DbFile",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_VideoFileUserInfos_AspNetUsers_UserId",
                table: "VideoFileUserInfos",
                column: "UserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_VideoFileUserInfos_DbFile_VideoFileId",
                table: "VideoFileUserInfos",
                column: "VideoFileId",
                principalTable: "DbFile",
                principalColumn: "Id");
        }
    }
}
