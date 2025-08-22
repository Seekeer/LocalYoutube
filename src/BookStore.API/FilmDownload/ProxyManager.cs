using System.Net.Http;
using System.Net;

namespace API.FilmDownload
{
    /// <summary>
    /// Manages proxy configuration for download operations
    /// </summary>
    public static class ProxyManager
    {
        /// <summary>
        /// Gets the proxy string for use in download commands
        /// </summary>
        /// <returns>The proxy configuration string</returns>
        public static string GetProxyString()
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

        /// <summary>
        /// Gets an HttpClient configured with proxy settings
        /// </summary>
        /// <returns>HttpClient with proxy configuration</returns>
        public static HttpClient GetHttpClientWithProxy()
        {
            // TODO: Implement actual proxy configuration logic
            // This is a placeholder implementation that returns a standard HttpClient
            return new HttpClient();
        }
    }
}