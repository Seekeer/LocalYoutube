﻿using API.Resources;
using Infrastructure;
using System.Threading.Tasks;

namespace FileStore.API.Configuration
{
    internal interface IStartupInitService
    {
        Task Init();
    }

    public class StartupInitService : IStartupInitService
    {
        private readonly DbUpdateManager _DbUpdateManager;

        public StartupInitService(DbUpdateManager dbUpdateManager) 
        {
            _DbUpdateManager = dbUpdateManager; 
        }

        public async Task Init()
        {
            _DbUpdateManager.AddOrUpdateVideoSeries(SeriesNames.OneTime, false, Domain.Models.VideoType.ExternalVideo);
            _DbUpdateManager.AddOrUpdateVideoSeries(SeriesNames.India, false, Domain.Models.VideoType.ExternalVideo);
        }
    }
}