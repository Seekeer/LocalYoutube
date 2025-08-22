using System.Net.Http;
using System.Net;

namespace API.FilmDownload
{
    public class ProxyManager
    {
        public static HttpClient GetHttpClientWithProxy()
        {
            return new HttpClient(new SocketsHttpHandler()
            {
                Proxy = new WebProxy($"socks5://194.28.224.70:1080")
                {
                    Credentials = new NetworkCredential(
                        userName: "dim",
                        password: "heheqwe")
                }
            });
        }

        public static string GetProxyString()
        {
            return $"socks5://dim:heheqwe@194.28.224.70:1080";
            //return $"http://timonin:BzNwuL4hrLgs@serv.bitterman.ru:3128";
            //return "https://webhook.site/770a622a-8c1e-4397-9d48-4bfa5948aded";
        }
    }
}
