using Shiny.Net.Http;
using CommunityToolkit.Mvvm.ComponentModel;
using Dtos;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Shiny.NET
{
    public partial class TESTMainViewModel : ObservableObject
    {
        public TESTMainViewModel( HttpTransferMonitor monitor
            )  {

            Monitor = monitor;
            if(!Monitor.IsStarted)
                monitor.Start();
        }

        [ObservableProperty]
        public HttpTransferMonitor _monitor;
    }
}