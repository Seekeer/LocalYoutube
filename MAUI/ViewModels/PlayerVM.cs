using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Dtos;
using MAUI.Pages;
using MAUI.Services;
using Sentry.Protocol;
using System.Collections.ObjectModel;
using static System.Runtime.InteropServices.JavaScript.JSType;
using Windows.Devices.Geolocation;

namespace MAUI.ViewModels
{
    public partial class PlayerVM : VMBase<VideoFileResultDto>
    {
        private readonly IAPIService _api;

        [ObservableProperty]
        private VideoFileResultDto _file;

        [ObservableProperty]
        private SeekPositionCollection _seekPositionCollection = new SeekPositionCollection();

        [ObservableProperty]
        private string _videoUrl;
        public PlayerVM(IAPIService api)
        {
            _api = api;

            _dtoAssign = AssignDTO;
        }

        private void AssignDTO(VideoFileResultDto dto)
        {
            this.File = dto;
            this.VideoUrl = HttpClientAuth.GetVideoUrlById(dto.Id);

            DownloadAndReplace().ConfigureAwait(true).GetAwaiter().GetResult();
        }

        private async Task DownloadAndReplace()
        {
            if (this.File == null || this.File.DurationMinutes > 60)
                return;

            var path = File.Id.ToString();

            var filePath = await DownloadManager.DownloadAsync(path, this.VideoUrl);
            VideoUrl = filePath;
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