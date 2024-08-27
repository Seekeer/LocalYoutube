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
using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using System.Diagnostics;
using Xabe.FFmpeg;

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
        private SeekPositionCollectionVM _seekPositionCollection = new SeekPositionCollectionVM();

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

        [ObservableProperty]
        private BookmarksVM _bookmarks;
        private double _lastPosition;
        private bool _pausedCalled;
        private System.Timers.Timer _positionTimer;

        public Player Page { get; internal set; }

        public PlayerVM(IAPIService api, IMAUIService positionRepository, DownloadManager downloadManager)
        {
            _api = api;
            _mauiDBService = positionRepository;
            _downloadManager = downloadManager;

            _dtoAssign = AssignDTO;

            (App.Current as App).CurrentPlayerVM = this;
        }

        public void Dispose()
        {
            _positionTimer?.Dispose();
        }

        private void AssignDTO(VideoFileResultDtoDownloaded dto)
        {
            this.File = dto;
            this.VideoUrl = dto.IsDownloaded ?
                dto.Path :
                HttpClientAuth.GetVideoUrlById(dto.Id);
            Bookmarks = new BookmarksVM(_api, () => Page.GetMedia().Position, dto.Id);

            Description = DescriptionRow.ParseDescription(dto.Description);

            ProcessFile();
        }


        private async Task ProcessFile()
        {
            var fileService = GetFileService();
            _mauiDBService.AddFileIfNeeded(File);

            //DownloadAndReplace();
        }

        public async Task InitMedia()
        {
            await UpdatePosition();
            StartPositionUpdateTimer();

            this.Page.GetMedia().StateChanged += PlayerVM_StateChanged;

            //Task.Delay(TimeSpan.FromMilliseconds(10000))
            //    .ContinueWith(async task =>
            //    {
            //        await UpdatePosition();
            //        StartPositionUpdateTimer();
            //    });
        }

        private void PlayerVM_StateChanged(object? sender, CommunityToolkit.Maui.Core.Primitives.MediaStateChangedEventArgs e)
        {
            var state = Page.GetMedia().CurrentState;
            if (state == CommunityToolkit.Maui.Core.Primitives.MediaElementState.Paused)
            {
                //var state = Page.GetMedia().CurrentState;
                //if (!_pausedCalled)
                {
                    _pausedCalled = true;
                    Bookmarks.Paused();
                }
            }
            else if (_pausedCalled)
            {
                Bookmarks.Resumed();
                _pausedCalled = false;
            }
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

            double? position = _mauiDBService.GetInfoById(File.Id)?.Position;

            try
            {
                // Try to get remote position - if it is newer - set to it.
                var remotePosition = await _api.GetPositionAsync(File.Id);
                if(remotePosition != null)
                {
                    if (await _mauiDBService.SetPositionAsync(File.Id, remotePosition))
                        position = remotePosition.Position;
                }
            }
            catch (Exception ex)
            {
            }

            if (position != null)
                await Page.SetPosition(TimeSpan.FromSeconds(position.Value));
        }

        private IMAUIService GetFileService()
        {
            return Application.Current.MainPage.Handler.MauiContext.Services.GetService<IMAUIService>();
        }

        private void StartPositionUpdateTimer()
        {
            _positionTimer = new System.Timers.Timer();
            _positionTimer.Elapsed += new ElapsedEventHandler(async (_, __) =>
            {
                await UpdatePositionByControl();
            });
            _positionTimer.Interval = 500;
            _positionTimer.Enabled = true;
        }

        public async Task UpdatePositionByControl()
        {
            try
            {
                var position = Page.GetMedia().Position.TotalSeconds;
                if (position < 3)
                    return;

                var positionDTO = new PositionDTO { Position = position };
                //using var fileService = GetFileService();
                //_mauiDBService.SetPositionAsync(File.Id, positionDTO);
                await _api.SetPositionAsync(File.Id, positionDTO);
                Trace.WriteLine($"Position : {position}");

                if (SeekPositionCollection.PositionUpdated(Page.GetMedia().Position))
                    ShowSnackWithNavigation();

                //if (_lastPosition == position)
                //{
                //    var state = Page.GetMedia().CurrentState;
                //    if (!_pausedCalled)
                //    {
                //        _pausedCalled = true;
                //        Bookmarks.Paused();
                //    }
                //}
                //else if (_pausedCalled)
                //{
                //    await Bookmarks.Resumed();
                //    _pausedCalled = false;
                //}

                //_lastPosition = position;
            }
            catch (Exception ex)
            {
            }
        }

        private void ShowSnackWithNavigation()
        {
            var snackbarOptions = new SnackbarOptions
            {
                ActionButtonTextColor = Colors.Purple,
                CornerRadius = new CornerRadius(10),
            };

            string text = $"Вы переместились";
            string actionButtonText = $"Вернуться обратно на {SeekPositionCollection.Positions.First().OriginalPositionStr}";
            Action action = async () => await Page.SetPosition(SeekPositionCollection.Positions.First().OriginalPosition);
            TimeSpan duration = TimeSpan.FromSeconds(3);

            if(DeviceInfo.Current.Platform == DevicePlatform.Android)
                Snackbar.Make(text, action, actionButtonText, duration, snackbarOptions).Show();
        }

        private async Task DownloadAndReplace()
        {
            //if(!this.File.IsDownloaded && (this.File == null || this.File.DurationMinutes > 60))
            //    return;

            //var filePath = await _downloadManager.DownloadAsync(File);
            //var position = Page.GetCurrentPosition();
            //VideoUrl = (filePath);
            //if(position.TotalSeconds > 5)
            //    await Page.SetPosition(position);
        }

        [RelayCommand]
        public async Task Refresh()
        {
            AssignDTO(File);
        }

        [RelayCommand]
        public async Task AddBookmark()
        {
            await Bookmarks.AddMarkAsync(Page.GetMedia().Position);
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

}