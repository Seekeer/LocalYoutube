using FileStore.Domain.Models;
using Infrastructure.Context;
using FileStore.Infrastructure.Repositories;
using FileStore.Domain.Interfaces;
using Dtos;
using FileStore.Domain.Dtos;
using Microsoft.EntityFrameworkCore;

namespace MAUI.Services
{
    public interface IMAUIService //: IRepository<FileUserInfo>
    {
        void AddFileIfNeeded(VideoFileResultDto file);
        FileUserInfo GetInfoById(int id);
        Task<bool> SetPositionAsync(int id, PositionDTO position);
        Task UpdateFilePathAsync(int fileId, string finalPath);
    }

    public class MAUIService : IMAUIService
    {
        private readonly MAUIDbContext _db;

        public MAUIService(MAUIDbContext dbContext) {

            _db = dbContext;
        }

        public FileUserInfo GetInfoById(int id)
        {
            return _db.FilesUserInfo.AsNoTracking().FirstOrDefault(x => x.DbFile.Id == id);
        }

        public void AddFileIfNeeded(VideoFileResultDto file)
        {
            var videoFile = new VideoFile { Id = file.Id, Name = file.Name, SeriesId = MauiProgram.SERIES_ID, SeasonId = MauiProgram.SEASON_ID };
            Task.Run(async () =>
            {
                using var fileService = GetFileService();
                await fileService.Add(videoFile);
            }).Wait();
        }

        public async Task<bool> SetPositionAsync(int id, PositionDTO positionDTO)
        {
            using var fileService = GetFileService();
            return await fileService.SetPosition(id, MauiProgram.USER_ID.ToString(), positionDTO.Position, positionDTO.UpdatedDate);
        }

        public async Task UpdateFilePathAsync(int fileId, string finalPath)
        {
            using var videoFileRepository = Application.Current.MainPage.Handler.MauiContext.Services.GetService<IVideoFileRepository>(); 

            var file = await videoFileRepository.GetById(fileId);
            file.Path = finalPath;
            await videoFileRepository.Update(file);
        }

        private IVideoFileService GetFileService()
        {
            return Application.Current.MainPage.Handler.MauiContext.Services.GetService<IVideoFileService>();
        }
    }
}
