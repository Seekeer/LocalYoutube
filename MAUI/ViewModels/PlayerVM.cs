using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using MAUI.Pages;
using MAUI.Services;
using System.Collections.ObjectModel;
using System.Timers;
using FileStore.Domain.Dtos;
using MAUI.Downloading;
using CommunityToolkit.Maui.Views;
using Infrastructure;
using System.Text.RegularExpressions;
using System.Linq;

namespace MAUI.ViewModels
{
    public partial class PlayerVM : VMBase<VideoFileResultDtoDownloaded>
    {
        private readonly IAPIService _api;
        private readonly IMAUIService _mauiDBService;
        private readonly DownloadManager _downloadManager;

        [ObservableProperty]
        private VideoFileResultDtoDownloaded _file;

        [ObservableProperty]
        private SeekPositionCollection _seekPositionCollection = new SeekPositionCollection();

        [ObservableProperty]
        private string _videoUrl;

        [ObservableProperty]
        private string _coverUrl;

        [ObservableProperty]
        private MediaSource _videoSource;

        [ObservableProperty]
        private TimeSpan _position;

        [ObservableProperty]
        private IEnumerable<DescriptionRow> _description;
        public Player Page { get; internal set; }

        public PlayerVM(IAPIService api, IMAUIService positionRepository, DownloadManager downloadManager)
        {
            _api = api;
            _mauiDBService = positionRepository;
            _downloadManager = downloadManager;

            _dtoAssign = AssignDTO;
            
        }

        private void AssignDTO(VideoFileResultDtoDownloaded dto)
        {
            this.File = dto;
            this.VideoUrl = HttpClientAuth.GetVideoUrlById(dto.Id);

            Description = DescriptionRow.ParseDescription(dto.Description);

            ProcessFile();
        }


        private async Task ProcessFile()
        {
            //using var fileService = GetFileService();
            _mauiDBService.AddFileIfNeeded(File);

            //DownloadAndReplace();
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
            aTimer.Interval = 2000;
            aTimer.Enabled = true;
        }

        public void UpdatePositionByControl()
        {
            var position = Page.GetCurrentPosition().TotalSeconds;
            if (position < 15)
                return;

            var positionDTO = new PositionDTO { Position = position };
            //using var fileService = GetFileService();
            _mauiDBService.SetPositionAsync(File.Id, positionDTO);
            _api.SetPositionAsync(File.Id, positionDTO);
        }

        private async Task DownloadAndReplace()
        {
            if(!this.File.IsDownloaded && (this.File == null || this.File.DurationMinutes > 60))
                return;

            var filePath = await _downloadManager.DownloadAsync(File);
            var position = Page.GetCurrentPosition();
            VideoUrl = (filePath);
            if(position.TotalSeconds > 5)
                await Page.SetPosition(position);
        }

        [RelayCommand]
        public async Task Play()
        {
        }

    }

    public class DescriptionRow
    {
        public DescriptionRow(string paragraph, string value)
        {
            Paragraph = paragraph;
            Timestamp = value;
        }

        public string Paragraph { get; }
        public string Timestamp { get; }

        public TimeSpan GetPosition()
        {
            var ts = TimeSpan.Parse(Timestamp);
            return ts;
        }

        private int CountInstances(string str, string substring)
        {
            return str.Split(substring).Length - 1;
        }

        public static IEnumerable<DescriptionRow> ParseDescription(string description)
        {
            var result = new List<DescriptionRow>();
            if (string.IsNullOrEmpty(description))
                return result;

            var paragraphs = description.SplitByNewLine().Select(paragraph =>
            {
                var convertedWords = paragraph.Trim().Split(" ");
                var firstWord = convertedWords[0];
                var match = Regex.Match(firstWord, @"((\d{1,2}:)?[0-5]?\d:[0-5]?\d)");
                if (match.Success)
                    return new DescriptionRow(paragraph.Replace(firstWord, ""), match.Value);
                else
                    return new DescriptionRow(paragraph, null);

            }).ToList();

            return paragraphs;
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
        List<SeekPosition> _positions  = new List<SeekPosition>();

        // TODO - for some reason throw Ex on adding. Threads?
        //[ObservableProperty]
        //private ObservableCollection<SeekPosition> _positions = new ObservableCollection<SeekPosition>();

        public bool TryAddPosition(List<TimeSpan> positions, TimeSpan newPosition)
        {
            try
            {

                var diffPositions = positions.Where(x => Math.Abs((newPosition - x).TotalSeconds) > 5);
                var originalPosition = diffPositions.LastOrDefault();

                if (newPosition == originalPosition)
                    return false;

                if (this.Positions.Count > 0)
                {

                    var lastPosition = this.Positions[this.Positions.Count - 1];
                    if (lastPosition.OriginalPosition == originalPosition)
                    {
                        lastPosition.NewPosition = newPosition;
                        return false;
                    }
                }

                if (this.Positions.Any(x => x.NewPosition == newPosition && x.OriginalPosition == originalPosition))
                    return false;

                var seekPosition = new SeekPosition();
                seekPosition.OriginalPosition = originalPosition;
                seekPosition.NewPosition = newPosition;
                //this.Positions.Add(seekPosition);

                this.Positions.Insert(0, seekPosition);
                this.Positions = new List<SeekPosition>(this.Positions);
                return true;
            }
            catch (Exception ex)
            {
                return false;
            }
        }
    } 
}