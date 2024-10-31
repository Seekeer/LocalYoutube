using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class CascadeDelete : Migration
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
                name: "FK_PlaylistItems_DbFile_FileId",
                table: "PlaylistItems");

            migrationBuilder.DropForeignKey(
                name: "FK_PlaylistItems_Playlists_PlaylistId",
                table: "PlaylistItems");

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
                name: "FK_PlaylistItems_DbFile_FileId",
                table: "PlaylistItems",
                column: "FileId",
                principalTable: "DbFile",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_PlaylistItems_Playlists_PlaylistId",
                table: "PlaylistItems",
                column: "PlaylistId",
                principalTable: "Playlists",
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
                name: "FK_PlaylistItems_DbFile_FileId",
                table: "PlaylistItems");

            migrationBuilder.DropForeignKey(
                name: "FK_PlaylistItems_Playlists_PlaylistId",
                table: "PlaylistItems");

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
                name: "FK_PlaylistItems_DbFile_FileId",
                table: "PlaylistItems",
                column: "FileId",
                principalTable: "DbFile",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_PlaylistItems_Playlists_PlaylistId",
                table: "PlaylistItems",
                column: "PlaylistId",
                principalTable: "Playlists",
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
