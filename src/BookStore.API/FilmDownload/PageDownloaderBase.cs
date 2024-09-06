using FileStore.Domain;
using HtmlAgilityPack;
using System.Collections.Generic;

namespace API.FilmDownload
{
    public abstract class PageDownloaderBase : DownloaderBase
    {
        protected PageDownloaderBase(AppConfig config, IWebPageLoader loader) : base(config)
        {
            _pageLoader = loader;
        }

        protected static Dictionary<string, HtmlDocument> _loadedPages = new();
        private readonly IWebPageLoader _pageLoader;

        protected HtmlDocument GetHTML(string url)
        {
            if(!_loadedPages.ContainsKey(url))
                _loadedPages.Add(url, _pageLoader.GetDocument(url));
            
            return _loadedPages[url];
        }

        public override void Dispose()
        {
            _pageLoader.Dispose();
            base.Dispose();
        }
    }
}