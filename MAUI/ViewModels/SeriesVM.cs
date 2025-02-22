﻿using CommunityToolkit.Mvvm.ComponentModel;
using FileStore.Domain.Models;
using MAUI.Downloading;
using MAUI.Services;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace MAUI.ViewModels
{
    public partial class SeriesVM : ListVM
    {
        private readonly IAPIService _aPIService;

        public SeriesVM(INavigationService navigationService, DownloadManager downloadManager, IAPIService aPIService) 
            : base(navigationService, downloadManager, aPIService)
        {
            _aPIService = aPIService;

            Init();
        }

        private async Task Init()
        {
            IsBusy = true;
            Series = (await _aPIService.GetSeries()).OrderBy(x => x.Name).ToList();
            Playlists = (await _aPIService.GetPlaylistsAsync()).OrderBy(x => x.Name).ToList();
            IsBusy = false;
        }

        [ObservableProperty]
        private IEnumerable<Playlist> _playlists;

        [ObservableProperty]
        private IEnumerable<Series> _series;
        //public IEnumerable<Series> Series
        //{
        //    get
        //    {
        //        return _aPIService.GetSeries();
        //    }
        //}

        public Series SelectedSeries
        {
            set
            {
                Seasons = value.Seasons.OrderBy(x => x.Name).ToList(); 
                _selectedSeries = value;
            }
            get
            {
                return _selectedSeries;
            }
        }


        public Playlist SelectedPlaylist
        {
            set
            {
                UpdateFiles(value);
            }
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

        private async Task UpdateFiles(Playlist playlist)
        {
            IsBusy = true;
            Files = new System.Collections.ObjectModel.ObservableCollection<VideoFileResultDtoDownloaded>(await _aPIService.GetFilesForPlaylist(playlist));
            IsBusy = false;
        }

        private async Task UpdateFiles(Season season)
        {
            IsBusy = true;
            Files = new System.Collections.ObjectModel.ObservableCollection<VideoFileResultDtoDownloaded>(await _aPIService.GetFilesForSeason(season.Id));
            IsBusy = false;
        }
    }
}
