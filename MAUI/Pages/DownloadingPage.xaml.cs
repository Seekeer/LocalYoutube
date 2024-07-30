using Shiny.Net.Http;
#if ANDROID
using static Android.Provider.MediaStore;
#endif
namespace Shiny.NET
{

    public partial class MainPage : ContentPage
    {
        public MainPage(TESTMainViewModel vm)
        {
            this.InitializeComponent();

            BindingContext = vm;
        }

        private static int _counter = 101028;

        private void Button_Clicked(object sender, EventArgs e)
        {
            const string Uri = "https://www.dwsamplefiles.com/?dl_id=349";
            startDownload(Uri);
        }
        private void Button_Clicked3(object sender, EventArgs e)
        {

            const string Uri = "http://server.audiopedia.su:8888/get_mp3_radio_128.php?id=38106";
            startDownload(Uri);
        }

        private static void startDownload(string Uri)
        {
            var manager = Application.Current.MainPage.Handler.MauiContext.Services.GetService<IHttpTransferManager>();

            var fileId = _counter++.ToString();


            var path = PlataformFolder();
            var fileWriteTo = Path.Combine(path, fileId);

            var task = manager.Queue(new HttpTransferRequest(fileId, Uri, false, fileWriteTo, true));

            var sub = manager.WatchTransfer(fileId).Subscribe(
                x =>
                {
                },
                ex =>
                {
                    // fires when an error outside of connectivity issues occur
                },
                () =>
                {
                    // fires when the transfer is complete
                }
            );
        }

        private static string PlataformFolder()
        {
            return FileSystem.AppDataDirectory;
        }

        private void Button_Clicked2(object sender, EventArgs e)
        {
            var manager = Application.Current.MainPage.Handler.MauiContext.Services.GetService<IHttpTransferManager>();
            manager.CancelAll();
        }

    }

}
