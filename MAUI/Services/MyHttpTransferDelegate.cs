using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Shiny.Net.Http;

namespace MAUI.Services
{
    public partial class MyHttpTransferDelegate : IHttpTransferDelegate
    {
        public MyHttpTransferDelegate()
        {
        }


        public Task OnCompleted(HttpTransferRequest request)
        {
            return Task.CompletedTask;
        }


        public Task OnError(HttpTransferRequest request, Exception ex)
        {
            return Task.CompletedTask;
        }
    }

//#if ANDROID
//    public partial class MyHttpTransferDelegate : IAndroidForegroundServiceDelegate
//    {
//        public void Configure(AndroidX.Core.App.NotificationCompat.Builder builder)
//        {
//            builder
//                .SetContentTitle("Your App")
//                .SetContentText("Sending Transfers in the background");
//        }
//    }
//#endif
}
