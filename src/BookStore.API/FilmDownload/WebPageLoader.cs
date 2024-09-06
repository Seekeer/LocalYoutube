using HtmlAgilityPack;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System;

namespace API.FilmDownload
{
    public interface IWebPageLoader : IDisposable
    {
        HtmlDocument GetDocument(string url, Encoding encoding = null);
        string GetStringDocument(string url);
    }

    public class WebPageLoader : IWebPageLoader
    {
        private readonly CircularList<WebProxy> _proxies;

        public WebPageLoader(bool useProxy)
        {
            if (!useProxy)
                return;

            var proxy = new WebProxy
            {
                Address = new Uri($"http://serv.bitterman.ru:3128"),
                BypassProxyOnLocal = false,
                UseDefaultCredentials = false,

                // *** These creds are given to the proxy server, not the web server ***
                Credentials = new NetworkCredential(
                            userName: "timonin",
                            password: "BzNwuL4hrLgs")
            };

            _proxies = new CircularList<WebProxy>(new WebProxy[] { proxy });
        }

        public WebPageLoader(IEnumerable<string> proxies = null)
        {
            if (proxies != null)
                _proxies = new CircularList<WebProxy>(proxies.Select(GetProxySettings).Where(x => x != null));
        }

        public WebPageLoader(IEnumerable<WebProxy> proxies)
        {
            if (proxies != null)
                _proxies = new CircularList<WebProxy>(proxies);
        }

        private WebProxy GetProxySettings(string proxy)
        {
            if (string.IsNullOrEmpty(proxy))
                return null;

            try
            {
                var splitted = proxy.Split('@');

                var port = splitted.Last().Split(':').Last();
                var settings = new WebProxy(splitted.Last().Replace(':' + port, ""), int.Parse(port));

                if (splitted.Length == 2)
                {
                    var passwordPart = splitted.First();
                    var credentials = new NetworkCredential(passwordPart.Split(':').First(), passwordPart.Split(':').Last());
                    settings.Credentials = credentials;
                }

                return settings;
            }
            catch (Exception)
            {
                return null;
            }
        }

        public HtmlDocument GetDocument(string url, Encoding encoding = null)
        {
            var mywebclient = new MyWebClient(_proxies?.GetItem());

            ServicePointManager.ServerCertificateValidationCallback += (sender, cert, chain, sslPolicyErrors) => true;
            var doc = new HtmlDocument();

            encoding = encoding ?? Encoding.UTF8;
            doc.Load(mywebclient.OpenRead(url), encoding);

            return doc;
        }

        public string GetStringDocument(string url)
        {
            var mywebclient = new MyWebClient(_proxies?.GetItem());

            ServicePointManager.ServerCertificateValidationCallback += (sender, cert, chain, sslPolicyErrors) => true;

            using (StreamReader reader = new StreamReader(mywebclient.OpenRead(url)))
            {
                return reader.ReadToEnd();
            }
        }

        public void Dispose()
        {
        }
    }

    class MyWebClient : WebClient
    {
        private WebProxy webProxy;

        public MyWebClient(WebProxy webProxy)
        {
            this.webProxy = webProxy;
        }

        protected override WebRequest GetWebRequest(Uri address)
        {
            HttpWebRequest request = base.GetWebRequest(address) as HttpWebRequest;
            request.UserAgent = "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.874.121 Safari/535.2";
            request.AutomaticDecompression = DecompressionMethods.Deflate | DecompressionMethods.GZip;

            if (webProxy != null)
                request.Proxy = webProxy;

            return request;
        }
    }

    public class CircularList<T> : List<T>, IEnumerable<T>
    {
        private int _index = 0;

        public CircularList(IEnumerable<T> enumerable) : base(enumerable)
        {
        }

        public T GetItem()
        {
            if (_index == this.Count - 1)
                _index = 0;

            return this[_index];
        }
    }
}
