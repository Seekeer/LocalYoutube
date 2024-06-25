using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using MAUI.Pages;
using MAUI.Services;
using Sentry.Protocol;
using System.Collections.ObjectModel;
using static System.Runtime.InteropServices.JavaScript.JSType;
using FileStore.Infrastructure.Repositories;
using Xabe.FFmpeg;
using FileStore.Domain.Models;
using FileStore.Domain.Interfaces;
using FileStore.Domain.Services;
using System.Timers;
using FileStore.Domain.Dtos;

namespace MAUI.ViewModels
{
    public partial class PlayerVM : VMBase<VideoFileResultDto>
    {
        private readonly IAPIService _api;
        private readonly IPositionRepository _positionRepository;
        private readonly IVideoFileService _fileService;
        private readonly DownloadManager _downloadManager;

        [ObservableProperty]
        private VideoFileResultDto _file;

        [ObservableProperty]
        private SeekPositionCollection _seekPositionCollection = new SeekPositionCollection();

        [ObservableProperty]
        private string _videoUrl;

        [ObservableProperty]
        private TimeSpan _position;

        public Player Page { get; internal set; }

        public PlayerVM(IAPIService api, IPositionRepository positionRepository, 
            IVideoFileService fileService, DownloadManager downloadManager)
        {
            _api = api;
            _positionRepository = positionRepository;
            _fileService = fileService;
            _downloadManager = downloadManager;

            _dtoAssign = AssignDTO;
        }

        private void AssignDTO(VideoFileResultDto dto)
        {
            this.File = dto;
            this.VideoUrl = HttpClientAuth.GetVideoUrlById(dto.Id);

            ProcessFile();
        }

        private async Task ProcessFile()
        {
            AddFileIfNeeded();

            UpdatePosition();

            DownloadAndReplace();
        }

        private void AddFileIfNeeded()
        {
            var file = new VideoFile { Id = File.Id, Name = File.Name, SeriesId = MauiProgram.SERIES_ID, SeasonId = MauiProgram.SEASON_ID };
            Task.Run(async () => await _fileService.Add(file)).Wait();
        }

        private async Task UpdatePosition()
        {
            // TODO async??
            //FileUserInfo localPosition = null;
            //var setLocalPositionTask = Task.Run(async () =>
            //{
            //    localPosition = await _positionRepository.GetById(File.Id);
            //    if (localPosition != null)
            //        await Page.PlayerElement.SeekTo(TimeSpan.FromSeconds(localPosition.Position));
            //});
            //var remotePositionTask = _api.GetPositionAsync(File.Id);
            //var remotePosition = await setLocalPositionTask.ContinueWith(async x => await remotePositionTask);

            var localPosition = _positionRepository.GetInfoById(File.Id);
            if (localPosition != null)
                await Page.SetPosition(TimeSpan.FromSeconds(localPosition.Position));

            try
            {
                var remotePosition = await _api.GetPositionAsync(File.Id);
                if (await _fileService.SetPosition(File.Id, MauiProgram.USER_ID.ToString(), remotePosition.Position, remotePosition.UpdatedDate))
                    await Page.SetPosition(TimeSpan.FromSeconds(remotePosition.Position));
            }
            catch (Exception ex)
            {
            }

            StartPositionUpdateTimer();
        }

        private void StartPositionUpdateTimer()
        {
            System.Timers.Timer aTimer = new System.Timers.Timer();
            aTimer.Elapsed += new ElapsedEventHandler((_,__) => UpdatePositionByControl());
            aTimer.Interval = 10000; 
            aTimer.Enabled = true;
        }

        private void UpdatePositionByControl()
        {
            var position = Page.GetCurrentPosition().TotalSeconds;
            if (position < 5)
                return;

            var positionDTO = new PositionDTO { Position = position };
            _fileService.SetPosition(File.Id, MauiProgram.USER_ID.ToString(), position, positionDTO.UpdatedDate);
            _api.SetPosition(File.Id, positionDTO);
        }

        private async Task DownloadAndReplace()
        {
            if (this.File == null || this.File.DurationMinutes > 60)
                return;

            var filePath = await _downloadManager.DownloadAsync(File.Id);
            var position = Page.GetCurrentPosition();
            VideoUrl = filePath;
            await Page.SetPosition(position);
        }

        [RelayCommand]
        public async Task Play()
        {
        }
    }

    public class SeekPosition
    {
        public TimeSpan OriginalPosition { get; set; }
        public TimeSpan NewPosition { get; set; }
    }

    public partial class SeekPositionCollection : ObservableObject
    {
        [ObservableProperty]
        private ObservableCollection<SeekPosition> _positions = new ObservableCollection<SeekPosition>();

        public void TryAddPosition(List<TimeSpan> positions, TimeSpan newPosition)
        {
            var diffPositions = positions.Where(x => Math.Abs((newPosition - x).TotalSeconds) > 5);
            var originalPosition = diffPositions.LastOrDefault();

            if (newPosition == originalPosition)
                return;

            if (this.Positions.Count > 0)
            {

                var lastPosition = this.Positions[this.Positions.Count - 1];
                if (lastPosition.OriginalPosition == originalPosition)
                {
                    lastPosition.NewPosition = newPosition;
                    return;
                }
            }

            if (this.Positions.Any(x => x.NewPosition == newPosition && x.OriginalPosition == originalPosition))
                return;

            var seekPosition = new SeekPosition();
            seekPosition.OriginalPosition = originalPosition;
            seekPosition.NewPosition = newPosition;
            this.Positions.Add(seekPosition);
        }
    } 
}