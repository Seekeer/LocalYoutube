using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using MAUI.Pages;
using MAUI.Services;
using System.Collections.ObjectModel;
using System.Timers;
using FileStore.Domain.Dtos;

namespace MAUI.ViewModels
{
    public partial class PlayerVM : VMBase<VideoFileResultDto>
    {
        private readonly IAPIService _api;
        private readonly IMAUIService _mauiDBService;
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

        public PlayerVM(IAPIService api, IMAUIService positionRepository, DownloadManager downloadManager)
        {
            _api = api;
            _mauiDBService = positionRepository;
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
            //using var fileService = GetFileService();
            _mauiDBService.AddFileIfNeeded(File);

            DownloadAndReplace();
        }

        public async Task InitPosition()
        {
            await UpdatePosition();
            StartPositionUpdateTimer();

            //Task.Delay(TimeSpan.FromMilliseconds(10000))
            //    .ContinueWith(async task => 
            //    {
            //        await UpdatePosition();
            //        StartPositionUpdateTimer();
            //    });
        }

        private async Task UpdatePosition()
        {
            // TODO async??
            //FileUserInfo localPosition = null;
            //var setLocalPositionTask = Task.Run(async () =>
            //{
            //    localPosition = await _mauiDBService.GetById(File.Id);
            //    if (localPosition != null)
            //        await Page.PlayerElement.SeekTo(TimeSpan.FromSeconds(localPosition.Position));
            //});
            //var remotePositionTask = _api.GetPositionAsync(File.Id);
            //var remotePosition = await setLocalPositionTask.ContinueWith(async x => await remotePositionTask);

            var localPosition = _mauiDBService.GetInfoById(File.Id);
            if (localPosition != null)
                await Page.SetPosition(TimeSpan.FromSeconds(localPosition.Position));

            try
            {
                // Try to get remote position - if it is newer - set to it.
                var remotePosition = await _api.GetPositionAsync(File.Id);
                if(remotePosition != null)
                {
                    //using var fileService = GetFileService();
                    if (await _mauiDBService.SetPositionAsync(File.Id, remotePosition))
                        await Page.SetPosition(TimeSpan.FromSeconds(remotePosition.Position));
                }
            }
            catch (Exception ex)
            {
            }
        }

        private IMAUIService GetFileService()
        {
            return Application.Current.MainPage.Handler.MauiContext.Services.GetService<IMAUIService>();
        }

        private void StartPositionUpdateTimer()
        {
            System.Timers.Timer aTimer = new System.Timers.Timer();
            aTimer.Elapsed += new ElapsedEventHandler((_,__) => UpdatePositionByControl());
            aTimer.Interval = 1000;
            aTimer.Enabled = true;
        }

        public void UpdatePositionByControl()
        {
            var position = Page.GetCurrentPosition().TotalSeconds;
            if (position < 5)
                return;

            var positionDTO = new PositionDTO { Position = position };
            //using var fileService = GetFileService();
            _mauiDBService.SetPositionAsync(File.Id, positionDTO);
            _api.SetPositionAsync(File.Id, positionDTO);
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