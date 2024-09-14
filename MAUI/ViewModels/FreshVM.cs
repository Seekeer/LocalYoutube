using CommunityToolkit.Mvvm.ComponentModel;
using FileStore.Domain.Models;
using MAUI.Downloading;
using MAUI.Services;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace MAUI.ViewModels
{
    public partial class FreshVM : ListVM
    {
        private readonly IAPIService _aPIService;

        public FreshVM(INavigationService navigationService, DownloadManager downloadManager, IAPIService aPIService) 
            : base(navigationService, downloadManager, aPIService)
        {
            _aPIService = aPIService;

            Init();
        }

        private async Task Init()
        {
            IsBusy = true;
            Seasons = (await _aPIService.GetNewSeasons()).ToList();
            IsBusy = false;
        }

        [ObservableProperty]
        private IEnumerable<Season> _seasons;
        private Series _selectedSeries;

        public Season SelectedSeason
        {
            set
            {
                UpdateFiles(value);
            }
        }

        private async Task UpdateFiles(Season season)
        {
            IsBusy = true;
            Files = new System.Collections.ObjectModel.ObservableCollection<VideoFileResultDtoDownloaded>(await _aPIService.GetFilesForSeason(season));
            IsBusy = false;
        }
    }
}
