using AngleSharp.Html.Parser;
using AngleSharp.Io;
using API.TG;
using FileStore.API;
using FileStore.Domain;
using FileStore.Domain.Models;
using Infrastructure;
using Microsoft.Win32;
using QBittorrent.Client;
using RuTracker.Client;
using RuTracker.Client.Model.SearchTopics.Request;
using RuTracker.Client.Model.SearchTopics.Response;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using YandexDisk.Client.Http;

namespace API.Controllers
{
    public interface IRuTrackerUpdater
    {
        string ClearFromForeignOption(string text);
        Task DeleteTorrent(string id);
        Task<VideoInfo> FillVideoInfo(int topicId);
        Task Init();
        Task<bool> MoveTorrent(int id, string newFolder);
        Task PauseTorrent(string id);
        Task<IReadOnlyList<TorrentContent>> StartDownload(int id, string rootDownloadFolder);
        Task UpdateVideoFile(bool updateCover, VideoFile file);
    }

    public class RuTrackerUpdater : IRuTrackerUpdater
    {
        private RuTrackerClient _client;
        private QBittorrentClient _qclient;
        private WebProxy _proxy;
        private HttpClient _httpClient;
        private readonly TorrentSettings _config;

        public RuTrackerUpdater(AppConfig config)
        {
            _config = config?.TorrentSettings;
        }

        public async Task Init()
        {
            _qclient = new QBittorrentClient(new Uri(_config.QBittorrentWebUI));

            _proxy = new WebProxy
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
            _httpClient = new HttpClient(handler: httpClientHandler, disposeHandler: true);
            RuTrackerClientEnvironment env = new RuTrackerClientEnvironment(_httpClient, new Uri(@"https://rutracker.org"));

            try
            {
                _client = new RuTrackerClient(env);
                await _client.Login(_config.RP_Login, _config.RP_Pass);
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }
        }


        public async Task UpdateVideoFile(bool updateCover, VideoFile file)
        {
            var info = await FillVideoInfo(file.VideoFileExtendedInfo.RutrackerId);

            file.Duration = info.Duration;
            file.Name = ClearFromForeignOption(info.Name);
            file.VideoFileExtendedInfo.Director = ClearFromForeignOption(info.Director);
            file.VideoFileExtendedInfo.Year = info.Year;
            file.VideoFileExtendedInfo.Genres = info.Genres;
            file.VideoFileExtendedInfo.Description = info.Description;

            if (file.Duration == System.TimeSpan.Zero)
                file.Duration = DbUpdateManager.GetDuration(file.Path);

            if (updateCover)
                file.VideoFileExtendedInfo.SetCover(info.Cover);
        }

        internal async Task<IEnumerable<TorrentInfo>> Get()
        {
            _qclient = new QBittorrentClient(new Uri("http://localhost:124"));

            var list = await _qclient.GetTorrentListAsync();
            var goodList = list.Where(x => x.AddedOn > new DateTime(2022, 08, 01, 18, 31, 00)).OrderBy(x => x.AddedOn).ToList();

            return goodList.Skip(1).SkipLast(1);
        }

        public async Task<VideoInfo> FillVideoInfo(int topicId)
        {
            string responseString = await GetTopicHTML(topicId);

            var parser = new RutrackerInfoParser();
            var info = await parser.ParseVideoInfo(responseString);

            return info;
        }

        public async Task<AudioInfo> FillAudioInfo(int topicId)
        {
            string responseString = await GetTopicHTML(topicId);

            var parser = new RutrackerInfoParser();
            var info = await parser.ParseAudioInfo(responseString);

            return info;
        }

        private async Task<string> GetTopicHTML(int topicId)
        {
            var url = $"https://rutracker.org/forum/viewtopic.php?t={topicId}";

            HttpResponseMessage response = await _httpClient.GetAsync(url);
            var buffer = await response.Content.ReadAsByteArrayAsync();
            byte[] bytes = buffer.ToArray();
            Encoding encoding = Encoding.GetEncoding("windows-1251");
            string responseString = encoding.GetString(bytes, 0, bytes.Length);
            return responseString;
        }

        internal void FillFileInfo(DbFile file, RutrackerInfo info)
        {
            file.VideoFileExtendedInfo.Description = info.Description;

            if (info.Cover != null && info.Cover.Length > 30 * 1024)
                file.VideoFileExtendedInfo.SetCover(info.Cover);
            file.VideoFileExtendedInfo.Year = info.Year;
            file.Duration = info.Duration;

            if(info is VideoInfo videoInf)
            {
                file.VideoFileExtendedInfo.Genres = videoInf.Genres;
                file.VideoFileExtendedInfo.Director = ClearFromForeignOption(videoInf.Director);
            }
            else if (info is AudioInfo audioInf)
            {
                file.VideoFileExtendedInfo.Director = audioInf.Voice;
            }
        }

        public string ClearFromForeignOption(string text)
        {
            return text.EndingBefore(@"/").EndingBefore(@"\");
        }


        public async Task<IEnumerable<SearchTopicInfo>> FindTheme(string name, CommandType? type)
        {
            var res = await _client.SearchTopics(new SearchTopicsRequest(
               Title: name,
               SortBy: SearchTopicsSortBy.Downloads,
               SortDirection: SearchTopicsSortDirection.Descending
           ));

            if (res.Topics.Count() < 5)
                return res.Topics;

            var topics = res.Topics.AsEnumerable();
            var takeCount = 15;
            long maxLimit = (long)300 * 1024 * 1024 * 1024;
            long minLimit = (long)1 * 1024;

            switch (type)
            {
                case CommandType.SearchAudioBook:
                    maxLimit = (long)3 * 1024 * 1024 * 1024;
                    minLimit = (long)10 * 1024 * 1024;
                    takeCount = 500;
                    break;
                case CommandType.ShowAllSearchResult:
                    // Show all.
                    break;
                default:
                    maxLimit = (long)30 * 1024 * 1024 * 1024;
                    minLimit = (long)1 * 1024 * 1024 * 1024;
                    break;
            }

            topics = topics.Where(x => x.SizeInBytes < maxLimit && x.SizeInBytes > minLimit);
            if (topics.Count() < 3)
                topics = res.Topics;

            topics = topics.Where(x => !x.Title.Contains("DVD9") && !x.Title.Contains("DVD5"));

            return topics.OrderByDescending(x => x.SizeInBytes).Take(takeCount);
        }

        public async Task<IReadOnlyList<TorrentContent>> StartDownload(int id, string rootDownloadFolder)
        {
            NLog.LogManager.GetCurrentClassLogger().Info($"Start download to {rootDownloadFolder}");

            var torrent = await _client.GetTopicTorrentFile(id);

            var temp = Path.Combine(rootDownloadFolder, $"{rootDownloadFolder}.torrent");

            var fInfo = new FileInfo(temp);
            if (!Directory.Exists(fInfo.DirectoryName))
                Directory.CreateDirectory(fInfo.DirectoryName);

            File.WriteAllBytes(temp, torrent);

            var request = new AddTorrentFilesRequest();
            request.SequentialDownload = true;
            request.TorrentFiles.Add(temp);
            request.DownloadFolder = rootDownloadFolder;
            request.Tags = new List<string> { id.ToString() };

            string hash = await StartDownload(id, request);
            if (hash == null)
            {
                // Probably we haven't started QBittorrent.
                StartQBittorrent();
                hash = await StartDownload(id, request);
            }

            return await _qclient.GetTorrentContentsAsync(hash);
        }

        private async Task<string> StartDownload(int id, AddTorrentFilesRequest request)
        {
            await _qclient.AddTorrentsAsync(request);
            var hash = await GetTorrentHash(id.ToString());
            return hash;
        }

        private void StartQBittorrent()
        {
            if (!string.IsNullOrEmpty(_config.QBittorrentPath))
            {
                Process.Start(_config.QBittorrentPath);
                Thread.Sleep(TimeSpan.FromSeconds(10));
            } 
        }

        public async Task<bool> MoveTorrent(int id, string newFolder)
        {
            try
            {
                if (id == 0)
                    return false;

                TorrentInfo torrent = await GetTorrent(id.ToString());

                if (torrent != null)
                {
                    await _qclient.SetLocationAsync(new string[] { torrent.Hash }, newFolder);
                    await _qclient.ResumeAsync(torrent.Hash);

                    return true;
                }
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }

            return false;
        }

        public async Task DeleteTorrent(string id)
        {
            if (id == "0")
                return;
            try
            {
                TorrentInfo torrent = await GetTorrent(id);

                if (torrent != null)
                {
                    await _qclient.PauseAsync(torrent.Hash);
                    await _qclient.DeleteAsync(torrent.Hash, true);
                }

            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }
        }

        public async Task PauseTorrent(string id)
        {
            if (id == "0")
                return;

            try
            {
                TorrentInfo torrent = await GetTorrent(id);

                if (torrent != null)
                {
                    await _qclient.PauseAsync(torrent.Hash);
                }

            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }
        }

        private async Task<string> GetTorrentHash(string id)
        {
            return (await GetTorrent(id))?.Hash;
        }

        private async Task<TorrentInfo> GetTorrent(string id)
        {
            var torrents = await _qclient.GetTorrentListAsync();
            var torrent = torrents.FirstOrDefault(x => x.Tags.Contains(id));
            return torrent;
        }
    }
}
