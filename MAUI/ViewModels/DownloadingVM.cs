using Shiny.Net.Http;
using CommunityToolkit.Mvvm.ComponentModel;
using Dtos;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.Input;

namespace Shiny.NET
{
    public partial class TESTMainViewModel : ObservableObject
    {
        public TESTMainViewModel( HttpTransferMonitor monitor, IHttpTransferManager manager
            )  {
            _manager = manager;
            Monitor = monitor;

            if(!Monitor.IsStarted)
                monitor.Start();

            TransfersUpdated();
            Monitor.Transfers.CollectionChanged += (_, __) => { TransfersUpdated(); };
        }

        private void TransfersUpdated()
        {
            Transfers = Monitor.Transfers.ToList();
        }

        [ObservableProperty]
        public HttpTransferMonitor _monitor;

        [ObservableProperty]
        public IEnumerable<HttpTransferObject> _transfers;
        private readonly IHttpTransferManager _manager;

        [RelayCommand]
        public async Task StopDownloadVideo(string transferId)
        {
            await _manager.Cancel(transferId);
        }
    }
}