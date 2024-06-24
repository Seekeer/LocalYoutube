using Dtos;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MAUI.Services
{
    public static partial class DownloadManager
    {
        static HttpClient Client = new HttpClient();

        public static void UseCustomHttpClient(HttpClient client)
        {
            if (client is null)
                throw new ArgumentNullException($"The {nameof(client)} can't be null.");

            Client.Dispose();
            Client = null;
            Client = client;
        }

        public static async Task<string> DownloadAsync(int fileId)
        {
            var name = fileId.ToString();
            return await DownloadManager.DownloadAsync(name, HttpClientAuth.GetVideoUrlById(fileId));
        }

        public static async Task<string> DownloadAsync(
            string fileName,
            string url,
            IProgress<double> progress = default(IProgress<double>),
            CancellationToken token = default(CancellationToken))
        {
            //if (!(file.IsValidString() && url.IsValidString()))
            //    throw new ArgumentNullException($"the {nameof(file)} and {nameof(url)} parameters can't be null.");

            //TODO colocar isso dentro de alguma pasta
            var path = PlataformFolder();
            var fileWriteTo = Path.Combine(path, fileName);

            if (File.Exists(fileWriteTo))
                return fileWriteTo;

            using (var response = await Client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead).ConfigureAwait(false))
            {
                if (!response.IsSuccessStatusCode)
                    throw new Exception($"Erro in download: {response.StatusCode}");

                var total = response.Content.Headers.ContentLength ?? -1L;

                using (var streamToReadFrom = await response.Content.ReadAsStreamAsync().ConfigureAwait(false))
                {
                    var totalRead = 0L;
                    var buffer = new byte[2048];
                    var isMoreToRead = true;
                    var output = new FileStream(fileWriteTo, FileMode.Create);
                    do
                    {
                        token.ThrowIfCancellationRequested();

                        var read = await streamToReadFrom.ReadAsync(buffer, 0, buffer.Length, token);

                        if (read == 0)
                            isMoreToRead = false;

                        else
                        {
                            await output.WriteAsync(buffer, 0, read);

                            totalRead += read;

                            progress?.Report((totalRead * 1d) / (total * 1d) * 100);
                        }

                    } while (isMoreToRead);

                    output.Close();
                    return fileWriteTo;
                }
            }
        }

        private static string PlataformFolder()
        {
            return FileSystem.AppDataDirectory;
            //#if ANDROID
            //            IWindowManager windowManager = Android.App.Application.Context.GetSystemService(Context.WindowService).JavaCast<IWindowManager>();
            //            SurfaceOrientation orientation = windowManager.DefaultDisplay.Rotation;
            //            bool isLandscape = orientation == SurfaceOrientation.Rotation90 || orientation == SurfaceOrientation.Rotation270;
            //            return isLandscape ? DeviceOrientation.Landscape : DeviceOrientation.Portrait;
            //#else
            //            return "";
            //#endif
        }
    }
}