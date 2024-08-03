using System.Net.Http;
using System;
using System.Net;
using YandexDisk.Client.Http;

namespace API.FilmDownload
{
    public class ProxyManager
    {
        public static HttpClient GetHttpClientWithProxy()
        {
            var _proxy = new WebProxy
            {
                Address = new Uri($"http://serv.bitterman.ru:3128"),
                BypassProxyOnLocal = false,
                UseDefaultCredentials = false,

                // *** These creds are given to the proxy server, not the web server ***
                Credentials = new NetworkCredential(
                userName: "timonin",
                password: "BzNwuL4hrLgs")
            };

            // Now create a client handler which uses that proxy
            var httpClientHandler = new HttpClientHandler
            {
                Proxy = _proxy,
                UseProxy = true,
            };

            // Finally, create the HTTP client object
            return new HttpClient(handler: httpClientHandler, disposeHandler: true);
        }

        public static string GetProxyString()
        {
            return $"http://timonin:BzNwuL4hrLgs@serv.bitterman.ru:3128";
            return "https://webhook.site/770a622a-8c1e-4397-9d48-4bfa5948aded";
        }
    }
}
