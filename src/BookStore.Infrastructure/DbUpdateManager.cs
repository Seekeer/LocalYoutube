using FileStore.Infrastructure.Context;
using System;
using System.Linq;
using System.Collections.Generic;
using System.IO;
using System.Text;
using FileStore.Domain.Models;
using System.Text.RegularExpressions;
using FFMpegCore;
using System.Drawing;
using System.Threading.Tasks;
using Xabe.FFmpeg;
using Microsoft.EntityFrameworkCore;
using Id3;
using System.Drawing.Drawing2D;
using FileStore.Domain.Interfaces;
using FileStore.Infrastructure.Repositories;
using Azure.Core;
using static MediaToolkit.Model.Metadata;
using System.IO.Compression;
using FileStore.Domain;
using System.Diagnostics;
using System.Diagnostics.Eventing.Reader;
using System.Net;
using Infrastructure.Migrations;

namespace Infrastructure
{

    public static class FileExtendedInfoExtension
    {
        public static void SetCoverByUrl(this FileExtendedInfo info, string url)
        {
            try
            {
                byte[] imageAsByteArray;
                using (var webClient = new WebClient())
                {
                    imageAsByteArray = webClient.DownloadData(url);
                }

                info.SetCover(imageAsByteArray);
            }
            catch (Exception)
            {
            }
        }

        public static void SetCover(this FileExtendedInfo info, byte[] cover)
        {
            info.Cover = ResizeImage(cover);
        }

        private static byte[] ResizeImage(byte[] cover)
        {
            if (cover == null)
                return cover;

            System.Drawing.Image img = null;
            using (var ms = new MemoryStream(cover))
            {
                img = Image.FromStream(ms);
            }

            var maxWidth = 1000;
            if (img.Width <= maxWidth)
                return cover;

            var newImag = ResizeImage(img, maxWidth);

            using (MemoryStream memoryStream = new MemoryStream())
            {
                newImag.Save(memoryStream, System.Drawing.Imaging.ImageFormat.Jpeg);

                return memoryStream.ToArray();
            }

        }
        private static System.Drawing.Image ResizeImage(System.Drawing.Image imgToResize, int newWidth)
        {
            // Get the image current width
            int sourceWidth = imgToResize.Width;
            // Get the image current height
            int sourceHeight = imgToResize.Height;
            float nPercent = 0;
            float nPercentW = 0;
            float nPercentH = 0;
            // Calculate width and height with new desired size
            nPercentW = ((float)newWidth / (float)sourceWidth);
            //nPercentH = ((float)size.Height / (float)sourceHeight);
            //nPercent = Math.Min(nPercentW, nPercentH);
            nPercent = nPercentW;
            // New Width and Height
            int destWidth = (int)(sourceWidth * nPercent);
            int destHeight = (int)(sourceHeight * nPercent);
            Bitmap b = new Bitmap(destWidth, destHeight);
            Graphics g = Graphics.FromImage((System.Drawing.Image)b);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            // Draw image with new width and height
            g.DrawImage(imgToResize, 0, 0, destWidth, destHeight);
            g.Dispose();
            return (System.Drawing.Image)b;
        }
    }

    public class DbUpdateManager : IDisposable
    {
        private Origin _origin;
        private VideoType? _type;
        private int _episodeNumber;
        private bool _ignoreNonCyrillic = true;
        private VideoCatalogDbContext _db;

        static DbUpdateManager()
        {
            //FFmpegDownloader.GetLatestVersion(FFmpegVersion.Official);

            var directory = new DirectoryInfo((@"Assets\downloadScript.txt"));

            GlobalFFOptions.Configure(new FFOptions { BinaryFolder = directory.Parent.FullName });
                FFmpeg.SetExecutablesPath(directory.Parent.FullName);
        }

        public DbUpdateManager(VideoCatalogDbContext db)
        {
            this._db = db;
        }

        public async Task UpdateFilesSeries()
        {
            var db = _db;

            var files = db.VideoFiles.ToList();
            var seasons = db.Seasons.ToList();
            var series = db.Series.ToList();

            foreach (var seasonGroup in files.GroupBy(x => x.SeasonId))
            {
                var season = seasons.First(x => x.Id == seasonGroup.Key);

                foreach (var file in seasonGroup)
                {
                    if (file.SeriesId != season.SeriesId)
                    {
                        if (file.SeriesId == 14)
                            file.SeasonId = 55;
                        else if (file.SeriesId == 6107)
                        {
                        }
                        else if (file.SeriesId == 6157)
                        {
                            file.SeasonId = 15048;
                        }
                        else
                            file.SeriesId = season.SeriesId;
                    }
                }
            }

            foreach (var file in files)
            {
                file.Type = series.First(x => x.Id == file.SeriesId).Type.Value;
            }

            await db.SaveChangesAsync();
        }


        public void FillFilms(string rootPath, Origin origin, VideoType type )
        {
            _origin = origin;
            _type = type;

            var dirInfo = new DirectoryInfo(rootPath);
            var series = AddOrUpdateVideoSeries(dirInfo.Name);

            AddSeason(series, dirInfo);

            _db.SaveChanges();
        }

        public void OperaBalley(string operaPath, string balleyPath, Origin origin, VideoType type)
        {
            _origin = origin;
            _type = type;

            var series = AddOrUpdateVideoSeries("Опера и балет");

            var dir = new DirectoryInfo(operaPath);
            var season = AddOrUpdateSeason(series, "Опера");
            AddSeason(series, season, dir);

            dir = new DirectoryInfo(balleyPath);
            season = AddOrUpdateSeason(series, "Балет");
            AddSeason(series, season, dir);
        }

        public void AddSeries(string rootPath, Origin origin, VideoType type, bool severalSeries = true, string seriesName = null)
        {
            _origin = origin;
            _type = type;

            _episodeNumber = 1;

            var dirInfo = new DirectoryInfo(rootPath);

            if (severalSeries)
            {
                foreach (var dir in dirInfo.GetDirectories())
                    AddSeries(dir, seriesName);
            }
            else
                AddSeries(dirInfo, seriesName);

            _db.SaveChanges();
        }

        public void Convert(VideoFile file, AppConfig config, bool encodeAlways = false)
        {
            try
            {
                var oldFile = file.Path;
                var helper = new VideoHelper(new FileManagerSettings(config));
                var newFilePath = helper.EncodeToMp4(file.Path, encodeAlways);

                if (newFilePath == null)
                    return;

                if (file.VideoFileExtendedInfo.Cover == null)
                    VideoHelper.FillVideoProperties(file);

                file.Path = newFilePath;
                _db.VideoFiles.Update(file);

                var updatedFile = _db.VideoFiles.FirstOrDefault(x => x.Id == file.Id);

                var fileToDelete = new VideoFile
                {
                    IsDownloading = true,
                    NeedToDelete = true,
                    Path = oldFile,
                    Name = "DELETE",
                    SeasonId = file.SeasonId,
                    SeriesId = file.SeriesId
                };
                _db.VideoFiles.Add(fileToDelete);

                _db.SaveChanges();

            }
            catch (Exception ex)
            {
            }
        }

        public void AddSeries(DirectoryInfo dir, string seriesName = null)
        {
            var series = AddOrUpdateVideoSeries(seriesName ?? dir.Name);

            var folders = dir.GetDirectories();

            if (!folders.Any())
                AddSeason(series, dir,null, false);
            else
            {
                foreach (var season in folders)
                    AddSeason(series, season);

                AddSeason(series, dir, null, false);
            }
        }

        public IEnumerable<VideoFile> AddSeason(int seriesId, string directory)
        {
            var serie = _db.Series.FirstOrDefault(x => x.Id == seriesId);

            return AddSeason(serie, new DirectoryInfo(directory));
        }

        public IEnumerable<VideoFile> AddSeason(int seriesId, DirectoryInfo dir, string seasonName = null)
        {
            var serie = _db.Series.FirstOrDefault(x => x.Id == seriesId);

            return AddSeason(serie, dir, seasonName);
        }

        public IEnumerable<VideoFile> AddSeason(Series series, DirectoryInfo dir, string seasonName = null, bool analyzeAll = true)
        {
            var season = AddOrUpdateSeason(series, seasonName ?? dir.Name);

            return AddSeason(series, season, dir, analyzeAll);
        }

        private IEnumerable<VideoFile> AddSeason(Series series, Season season, DirectoryInfo dir, bool analyzeAll = true)
        {
            var result = new List<VideoFile>();
            var files = analyzeAll ? dir.EnumerateFiles("", SearchOption.AllDirectories) : dir.EnumerateFiles("", SearchOption.TopDirectoryOnly);
            foreach (var file in files)
                result.Add(AddFile(file, series, season));

            return result.Where(x => x != null);
        }

        private VideoFile AddFile(FileInfo file, Series series, Season season)
        {
            try
            {
                if (IsBadExtension(file, false))
                    return null;

                var existingInfo = _db.VideoFiles.FirstOrDefault(x => x.Path == file.FullName && x.SeriesId == series.Id);
                VideoFile videoInfo = GetVideoInfo(series, season, file, existingInfo);
                if (existingInfo == null)
                    _db.VideoFiles.Add(videoInfo);

                _db.SaveChanges();

                return videoInfo;
            }
            catch (Exception ex)
            {
                //NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }

            return null;
        }

        private bool IsBadExtension(FileInfo file, bool isAudio)
        {
            var badExtension = file.Name.EndsWith("jpg") || file.Name.EndsWith("jpeg") || file.Name.EndsWith("docx") || file.Name.EndsWith("png") ||
                                file.Name.EndsWith("nfo") ||  file.Name.EndsWith("txt") || file.Name.EndsWith("pdf") ||
                                file.Name.EndsWith("xlsx") || file.Name.EndsWith("pdf") || file.Name.EndsWith("zip") || file.Name.EndsWith("vtt") ||
                                file.Name.EndsWith("srt") || file.Name.EndsWith("rar") || file.Name.EndsWith("zip") || file.Name.EndsWith("vtt") ||
                                file.Name.EndsWith("pptx") || file.Name.EndsWith("html") || file.Name.EndsWith("qB") || file.Name.EndsWith("lnk") ||
                                file.Name.EndsWith("mka") || file.Name.EndsWith("ass") || file.Name.EndsWith("tff") || file.Name.EndsWith("dts") ||
                                (file.FullName.Contains("Конспект") && _type == VideoType.Courses);

            if (isAudio)
                return badExtension;

            return badExtension || file.Name.EndsWith("ac3") || file.Name.EndsWith("mp3") || file.Name.EndsWith("ogg");
        }

        public void MoveToFolder(VideoFile file)
        {
            {
                var info = new FileInfo(file.Path);
                var newFilePath = Path.Combine(@"F:\Видео\Фильмы\Загрузки", info.Name);
                var oldDirectory = info.DirectoryName;
                info.MoveTo(newFilePath);
                file.Path = newFilePath;
                _db.SaveChanges();
                Directory.Delete(oldDirectory, true);
            }
        }

        public Season AddOrUpdateSeason(string seasonName, string seriesName, VideoType type)
        {
            var series = AddOrUpdateVideoSeries(seriesName, false, type);
            return AddOrUpdateSeason(series.Id, seasonName);
        }

        public Season AddOrUpdateSeason(int seriesId, string name)
        {
            var serie = _db.Series.FirstOrDefault(x => x.Id == seriesId);

            return AddOrUpdateSeason(serie, name);
        }

        public Season AddOrUpdateSeason(Series series, string name)
        {
            var season = _db.Seasons.FirstOrDefault(x => x.Name == name && x.SeriesId == series.Id);
            if (season == null )
            {
                season = new Season { Name = name, Series = series };
                season.IsOrderMatter = _type == VideoType.Courses;
                _db.Seasons.Add(season);
                _db.SaveChanges();
            }

            return season;
        }

        public Series GetDownloadSeries()
        {
            return AddOrUpdateVideoSeries("Загрузки", false);
        }

        public Series AddOrUpdateVideoSeries(string folderName, bool analyzeNameLikeFolderName = true, VideoType? type = null, bool isOrderMatter =false)
        {
            if (type == null)
                type = _type;

            var series = AddOrGetSeries(folderName, analyzeNameLikeFolderName, 
                type == VideoType.ChildEpisode || type == VideoType.FairyTale || type == VideoType.Animation);
            if(type != null)
                series.Type = type;

            _db.SaveChanges();
            return series;
        }

        public Series AddOrGetSeries(string folderName, bool analyzeFolderName, bool isChild, bool isOrderMatter = false)
        {
            var name = analyzeFolderName ? GetSeriesNameFromFolder(folderName) : folderName;

            var series = _db.Series.FirstOrDefault(x => x.Name == name);
            if (series == null)
            {
                series = new Series { Name = name, Origin = _origin };
                series.IsOrderMatter = isOrderMatter;
                series.IsChild = isChild;
                _db.Series.Add(series);
                _db.SaveChanges();
            }

            return series;
        }

        public static string GetSeriesNameFromFolder(string name)
        {
            string pattern = @"\p{IsCyrillic}";

            if (!Regex.IsMatch(name.ToString(), pattern))
                return name;

            var result = "";
            var index = 0;
            foreach (var ch in name)
            {
                if (!Regex.IsMatch(ch.ToString(), pattern))
                    if (ch != '-' && ch != '.' && ch != '!' && ch != ',' && !char.IsWhiteSpace(ch))
                        continue;

                index++;
                result += ch;
            }

            return result.ClearSerieName();
        }

        public string GetEpisodeNameFromFilenName(string name)
        {
            _ignoreNonCyrillic = false;
            if(_type == VideoType.Courses)
            {
                name = name.Replace("_", " ");

                return name;
            }
            name = name.Replace("_", " ").Replace("1080p.m4v", " ").Replace("HD", " ").Replace("720p", " ").Replace(".mkv", "");

            var result = "";
            string pattern = @"\p{IsCyrillic}";
            foreach (var ch in name)
            {
                if (_ignoreNonCyrillic &&!Regex.IsMatch(ch.ToString(), pattern))
                    if (ch != '-' && ch != '.' && ch != '!' && ch != ',' && !char.IsWhiteSpace(ch))
                        continue;

                result += ch;
            }

            return TrimDots(result);
        }

        private static string TrimDots(string result)
        {
            return result.Trim().Trim('.').Trim().Trim('-').Trim();
        }

        private VideoFile GetVideoInfo(Series series, Season season, FileInfo file, VideoFile video)
        {
            if (video == null)
                video = new VideoFile();

            return FillVideoInfo(series, season, file, video);
        }

        private VideoFile FillVideoInfo(Series series, Season season, FileInfo file, VideoFile video)
        {
            video.Name = GetEpisodeNameFromFilenName(file.Name).ClearFileName();
            video.Path = file.FullName;
            video.Type = _type ?? VideoType.Unknown;
            video.Origin = _origin;
            video.Series = series;
            video.Season = season;
            video.Number = _episodeNumber++;

            if (_type == VideoType.ChildEpisode)
            {
                video.Number = GetSeriesNumberFromName(file.Name);
            }

            VideoHelper.FillVideoProperties(video);

            return video;
        }

        public static async Task CombineStreams(string path)
        {
            var dir = new DirectoryInfo(path);
            var files = dir.EnumerateFiles("*", SearchOption.AllDirectories);

            if (files.Count() > 10)
                return;

            var biggest = files.OrderByDescending(x => x.Length).First();

            if (biggest.Length < 1024 * 1024 * 100)
                return;

            var pathOriginal = biggest.FullName;
            var index = 0;
            var path22 = Path.Combine(biggest.DirectoryName, index++.ToString(), biggest.Name);

            IMediaInfo fullMediaInfo = await FFmpeg.GetMediaInfo(pathOriginal);
            var subtitles = files.Where(x => x.Extension == ".srt");
            if (subtitles.Any())
            {
                var conversionSrt = await FFmpeg.Conversions.FromSnippet.AddSubtitle(pathOriginal, path22, subtitles.FirstOrDefault().FullName, DetectLanguage(subtitles.FirstOrDefault()));
                foreach (var subtitle in subtitles.Skip(1))
                {
                    IMediaInfo mediaInfo = await FFmpeg.GetMediaInfo(subtitle.FullName);

                    IStream videoStream = mediaInfo.SubtitleStreams.FirstOrDefault();
                    conversionSrt.AddStream(videoStream);
                }
                conversionSrt.SetVideoBitrate(fullMediaInfo.VideoStreams.FirstOrDefault().Bitrate);
                await conversionSrt.Start();
            }
            IEnumerable<FileInfo> audioFiles = files.Where(x => x.Extension == ".dts" || x.Extension == ".ac3" || x.Extension == ".mp3");
            if (audioFiles.Any())
            {
                var path23 = Path.Combine(biggest.DirectoryName, index++.ToString() + biggest.Name);
                var conversion = await FFmpeg.Conversions.FromSnippet.AddAudio(path22, audioFiles.First().FullName, path23);
                foreach (var audio in audioFiles.Skip(1))
                {
                    IMediaInfo mediaInfo = await FFmpeg.GetMediaInfo(audio.FullName);

                    IStream videoStream = mediaInfo.AudioStreams.FirstOrDefault();
                    conversion.AddStream(videoStream);
                }
                await conversion.Start();
            }
        }

        private static string DetectLanguage(FileInfo fileInfo)
        {
            throw new NotImplementedException();
        }

        public static TimeSpan GetDuration(string path)
        {
            try
            {
                var probe = FFProbe.Analyse(path);
                return probe.Duration;
            }
            catch (Exception ex)
            {
                return TimeSpan.Zero;
            }
        }

        public void UpdateAllImages()
        {
            var files = _db.FilesInfo;
            foreach (var file in files) 
            {
                try
                {
                    file.SetCover(file.Cover);
                    _db.SaveChanges();
                }
                catch (Exception e)
                {

                }
            }
        }

        public static int GetSeriesNumberFromName(string name)
        {
            var numberStr = Regex.Match(name, @"\d+\.*\d*").Value;
            if (numberStr.Length == 0)
                return 0;
            else
                return int.Parse(TrimDots(numberStr));
        }

        public IEnumerable<DbFile> UpdateDownloading(Func<DbFile, bool> selectFiles)
        {
            var ready = new List<DbFile>();
            IEnumerable<DbFile> queue = _db.Files
                .Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).Include(x => x.Series).Include(x => x.Season)
                .Where(selectFiles).ToList();

            _ignoreNonCyrillic = true;
            //ready.AddRange(UpdateEpisodes(queue, VideoType.ChildEpisode));
            //queue = queue.Except(ready);
            _ignoreNonCyrillic = false;
            ready.AddRange(UpdateFiles(queue));
            queue = queue.Except(ready);
            //ready.AddRange(UpdateEpisodes(queue, VideoType.AdultEpisode));
            //queue = queue.Except(ready);

            //var online = ready.Where(x => (new IsOnlineVideoAttribute()).HasAttribute(x.Type));

            //foreach (var item in online)
            //    Convert(item);

            return ready;
        }

        private IEnumerable<VideoFile> UpdateEpisodes(IEnumerable<VideoFile> files, VideoType type)
        {
            var result = new List<VideoFile>();

            var episodes = files.Where(x => x.Type == type);
            foreach (var info in episodes)
            {
                var dir = new DirectoryInfo(info.Path);

                if (!dir.Exists)
                {
                    //RemoveFileCompletely(info);
                    continue;
                }
                var series = _db.Series.First(x => x.Id == info.SeriesId);
                var season = _db.Seasons.First(x => x.Id == info.SeasonId);

                var dirFiles = dir.EnumerateFiles("*", SearchOption.AllDirectories);

                if (!dirFiles.Any() || dirFiles.Any(x => x.FullName.EndsWith(".!qB")))
                    continue;

                foreach (var file in dirFiles)
                {
                    if (info.IsDownloading && !IsBadExtension(file, false))
                    { 
                        info.Path = file.FullName;
                        //info.IsDownloading = false;
                        _db.SaveChanges();
                    }

                    var addedFile = AddFile(file, series, season);

                    if (addedFile == null)
                        continue;

                    addedFile.Type = type;
                    addedFile.IsDownloading = false;
                    VideoHelper.FillVideoProperties(addedFile);
                    result.Add(addedFile);
                }

            }

            _db.SaveChanges();

            return result;
        }

        private IEnumerable<DbFile> UpdateFiles(IEnumerable<DbFile> files, int? newSeasonId = null)
        {
            var result = new List<DbFile>();

            foreach (var info in files.Where(x => x is not VideoFile || (x as VideoFile).Type != VideoType.ExternalVideo))
            {
                try
                {
                    if(info.Path.EndsWith("!qB"))
                    {
                        var fInfo = new FileInfo(info.Path);
                        if (fInfo.Exists)
                            continue;

                        info.Path = fInfo.DirectoryName;
                    }

                    var dir = new DirectoryInfo(info.Path);

                    if (!dir.Exists)
                    {
                        //RemoveFileCompletely(info);
                        continue;
                    }

                    var dirFiles = dir.EnumerateFiles("*", SearchOption.AllDirectories);
                    if (!dirFiles.Any())
                    {
                        //// Delete db file if not exist
                        //RemoveFileCompletely(info);
                        //dir.Delete();
                        continue;
                    }

                    var dirDirectories = dir.EnumerateDirectories();
                    if (dirDirectories.Any(x => x.Name == "VIDEO_TS") || dirFiles.Any(x => x.Name.Contains("VIDEO_TS"))
                        || dirDirectories.Any(x => x.Name == "BDMV") || dirFiles.Any(x => x.FullName.Contains("BDMV")))
                        // TODO - message about wrong format
                        continue;

                    if (!dirFiles.Any() || dirFiles.Any(x => x.FullName.EndsWith(".!qB")))
                        continue;

                    dirFiles = dirFiles.Where(x => !IsBadExtension(x, info is AudioFile));

                    if(dirFiles.Count() > 1)
                    {
                        var moreFilesAdded = false;
                        var twoBiggest = dirFiles.OrderByDescending(x => x.Length).Take(2);

                        ResetUpdateManager(info);

                        var processResult = (info is VideoFile) ?
                            ProccessDownloadedVideoFile(info as VideoFile, dir, dirDirectories) :
                            AddAudioFilesByFile(dir, info as AudioFile);

                        if (processResult.Count() > 1)
                        {
                            processResult.ToList().ForEach(x => x.VideoFileExtendedInfo.RutrackerId = info.VideoFileExtendedInfo.RutrackerId);
                            var fileRepo = new DbFileRepository(_db);
                            fileRepo.RemoveFileCompletely(info.Id);
                            _db.SaveChanges();
                            continue;
                        }
                    }

                    var biggestFile = dirFiles.OrderByDescending(x => x.Length).First();

                    info.Path = biggestFile.FullName;
                    info.IsDownloading = false;

                    result.Add(info);

                    if (newSeasonId != null)
                        info.SeasonId = newSeasonId.Value;
                }
                catch (System.Exception ex)
                {
                    NLog.LogManager.GetCurrentClassLogger().Error(ex);
                }
            }

            _db.SaveChanges();

            return result;
        }

        private IEnumerable<DbFile> ProccessDownloadedVideoFile(VideoFile info, DirectoryInfo dir, IEnumerable<DirectoryInfo> dirDirectories)
        {
            var result = new List<DbFile>();

            if (info.Type == VideoType.Art)
            {
                _type = info.Type;
                var newFiles = AddSeason(info.SeriesId, dir, info.Name);
                newFiles.ToList().ForEach(x => x.VideoFileExtendedInfo.SetCover(info.Cover));
                result.AddRange(newFiles);
            }
            // Check that files ~ same size => they are series.
            else if (info.Series.Type == VideoType.AdultEpisode || info.Series.Type == VideoType.ChildEpisode
                || info.Series.Type == VideoType.FairyTale)
            {
                if (dirDirectories.Count() > 1)
                {
                    foreach (var seasonDirectory in dirDirectories)
                        result.AddRange(AddSeason(info.Series, seasonDirectory));
                }
                else
                {
                    IEnumerable<VideoFile> dbFiles = null;
                    dbFiles = AddSeason(info.Series, dir, info.Name);

                    if (string.IsNullOrWhiteSpace(info.Season.Name))
                        info.Season.Name = info.Series.Name;

                    result.AddRange(dbFiles);
                }
            };

            return result;
        }

        private void ResetUpdateManager(DbFile info)
        {
            _origin = info.Origin;
            _episodeNumber = 0;
        }

        public void UpdateChildRutracker(string path)
        {
            var series = GetDownloadSeries();

            var childDownloaded = AddOrUpdateSeason(series, "Детские мультики");
            var child = _db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).Where(x => x.Id >= 3533 && x.Id <= 3553).ToList();
            child.AddRange(_db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).Where(x => x.Id >= 3530 && x.Id <= 3530));
            child.AddRange(_db.VideoFiles.Include(x => x.VideoFileUserInfos).Include(x => x.VideoFileExtendedInfo).Where(x => x.Id >= 3565 && x.Id <= 3565));
            foreach (var item in child)
            {
                item.Type = VideoType.Animation;
                item.Season = childDownloaded;
                _db.SaveChanges();
            }
        }

        public void RemoveSeriesCompletely(int seriesId)
        {
            List<DbFile> files = new List<DbFile>();
            files.AddRange(_db.VideoFiles.Where(x => x.SeriesId == seriesId).Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileExtendedInfo));
            files.AddRange(_db.AudioFiles.Where(x => x.SeriesId == seriesId).Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileExtendedInfo));
            using var fileRepo = new DbFileRepository(_db);
            foreach (var file in files)
                fileRepo.RemoveFileCompletely(file.Id);

            var seasons = _db.Seasons.Where(x => x.SeriesId == seriesId);
            _db.Seasons.RemoveRange(seasons);

            var serie = _db.Series.FirstOrDefault(x => x.Id == seriesId);
            if(serie != null)
            _db.Series.Remove(serie);
            _db.SaveChanges();
        }

        public void RemoveFileCompletely(DbFile file)
        {
            var fileRepo = new DbFileRepository(_db) ;
            fileRepo.RemoveFileCompletely(file.Id);
        }

        public void UpdateAudioInfo(AudioFile audioFile)
        {
            using (var mp3 = new Mp3(audioFile.Path))
            {
                Id3Tag tag = mp3.GetTag(Id3TagFamily.Version2X);

                if (tag != null)
                {
                    audioFile.Name = tag.Title ?? audioFile.Name;
                    audioFile.VideoFileExtendedInfo.Cover = tag.Pictures.FirstOrDefault()?.PictureData;
                    audioFile.Artist = tag.Artists?.Value.FirstOrDefault();
                }

            }

            try
            {
                var probe = FFProbe.Analyse(audioFile.Path);
                audioFile.Duration = probe.Duration;
            }
            catch (Exception ex)
            {
            }
        }

        public IEnumerable<AudioFile> AddAudioFilesFromFolder(string folderPath, AudioType type, Origin origin, bool severalSeriesInFolder = false
            , string bookTitle = null, string author = null)
        {
            var result = new List<AudioFile>();
            try
            {
                var dirInfo = new DirectoryInfo(folderPath);
                if (!dirInfo.Exists)
                    return result;

                var title = bookTitle?? dirInfo.Name;

                if (severalSeriesInFolder)
                {
                    foreach (var dir in dirInfo.GetDirectories())
                        result.AddRange(AddAudioFilesFromFolder(dir, type, origin, new AudioFileInfo(title, author)));
                }
                else
                    result.AddRange(AddAudioFilesFromFolder(dirInfo, type, origin, new AudioFileInfo(title, author)));
            }
            catch (Exception ex)
            {
                //NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }

            return result;
        }

        private IEnumerable<DbFile> AddAudioFilesByFile(DirectoryInfo dir, AudioFile audioFile)
        {
            return AddAudioFilesFromFolder(dir, audioFile.Type, audioFile.Origin, new AudioFileInfo(audioFile.Season.Name, audioFile.Series.Name) { Voice = audioFile.Director});
        }

        public IEnumerable<AudioFile> AddAudioFilesFromFolder(DirectoryInfo dirInfo, AudioType type, Origin origin, AudioFileInfo bookInfo)
        {
            var result = new List<AudioFile>();
            if (!dirInfo.Exists)
                return result;
            var folderName = dirInfo.FullName;

            var series = type == AudioType.FairyTale ? AddOrUpdateVideoSeries(bookInfo.Author) :
                AddOrUpdateVideoSeries(type.ToString());
            series.AudioType = type;
            var season = AddOrUpdateSeason(series, bookInfo.BookTitle);

            return AddAudioFiles(dirInfo, type, origin, bookInfo, series, season);
        }

        private IEnumerable<AudioFile> AddAudioFiles(DirectoryInfo dirInfo, AudioType type, Origin origin, AudioFileInfo bookInfo, 
            Series series, Season season)
        {
            var files = new List<AudioFile>();
            IEnumerable<FileInfo> filePaths = dirInfo.EnumerateFiles("*", SearchOption.TopDirectoryOnly);
            var images = filePaths.Where(x => x.FullName.Contains(".jp")).OrderByDescending(x => x.Length);
            byte[] cover = null;
            if (images.Any())
                cover = File.ReadAllBytes(images.FirstOrDefault().FullName);

            var mp3s = filePaths.Where(x => x.Name.EndsWith(".mp3"));
            foreach (var item in mp3s.Select((info, index) => (info, index)))
            {
                var finfo = item.info;
                var filename = bookInfo.ClearFileName(finfo.Name);

                var audioFile = new AudioFile
                {
                    Season = season,
                    Series = series,
                    Path = finfo.FullName,
                    Name = filename,
                    Number = item.index + 1,
                    Type = type,
                    Origin = origin,
                };

                UpdateAudioInfo(audioFile);

                audioFile.VideoFileExtendedInfo.Director = bookInfo.Voice;
                files.Add(audioFile);
            }

            if (cover != null)
            {
                var file = files.First();
                file.VideoFileExtendedInfo.SetCover(cover);
            }

            _db.AudioFiles.AddRange(files);
            _db.SaveChanges();

            return files;
        }

        public void AddAudioFilesFromTg(string text, IEnumerable<string> enumerable, AudioType type, Origin origin, string coverImage)
        {
            var rows = text.SplitByNewLine().ToList();

            var artistName = rows.Count > 0 ? rows[0] : "Аудио";
            var albumName = rows.Count > 1 ? rows[1] : "Неизвестный";

            var isChild = type == AudioType.FairyTale;
            var season = AddOrGetSeries("Неизвестное из Telegram", false, isChild);
            season.AudioType = type;

            var seasonName = $"{artistName} - {albumName}";
            var album = AddOrUpdateSeason(season, seasonName);

            var files = new List<AudioFile>();
            foreach (var item in enumerable.Select((path, index) => (path, index)))
            {
                var fInfo = new FileInfo(item.path);

                var filename = fInfo.Name.Split("##").First().Replace(".mp3","");

                var audioFile = new AudioFile
                {
                    Season = album,
                    Series = season,
                    Path = item.path,
                    Name = filename,
                    Number = item.index + 1,
                    Type = type,
                    Origin = origin,
                };

                UpdateAudioInfo(audioFile);
                files.Add(audioFile);
            }

            var start = new string[] { "читает", "читают", "чит.", "в ролях", "исполнител", "исп.", "рассказчик" };
            var voice = rows.FirstOrDefault(x => start.Any(y => x.ToLower().Contains(y)));
            if (voice != null)
            {
                start.ToList().ForEach(x => voice = voice.Replace(x, ""));
                voice.Trim(' ', '-', ':', '.');

                files.ForEach(x => x.VideoFileExtendedInfo.Director = voice);
            }

            if (!string.IsNullOrEmpty(coverImage))
            {
                var file = files.First();

                file.VideoFileExtendedInfo.SetCover(File.ReadAllBytes(coverImage));
            }

            foreach (var file in files)
            {
                if(!_db.AudioFiles.Any(x => x.Name == file.Name))
                    _db.AudioFiles.AddRange(files);
            }
            _db.SaveChanges();
        }

        public void Dispose()
        {
            _db.Dispose();
        }

        public async Task AddAllCourcesFromFolder(string folder, AppConfig config)
        {
            foreach (var file in Directory.GetFiles(folder, "*zip"))
            {
                await AddSingleCourceFromArchive(file, config);
            }
        }

        public async Task AddSingleCourceFromArchive(string archivePath, AppConfig config)
        {
            try
            {
                _origin = Origin.Russian;
                _type = VideoType.Courses;

                var fInfo = new FileInfo(archivePath);

                const string watermark = "[SW.BAND] ";
                var cleared = fInfo.Name.Replace(watermark, "").Replace(".zip", "");

                var parts = cleared.Split(']', '(');
                var author = parts.First().Trim('[');
                var courseName = parts.ElementAt(1).Trim();

                var folder = new DirectoryInfo(fInfo.FullName.Replace(".zip", ""));
                ZipFile.ExtractToDirectory(archivePath, folder.Parent.FullName);
                foreach (var file in folder.GetFiles())
                {
                    if (file.Name == "[SW.BAND] Прочти перед изучением!.docx" || file.Name == "SHAREWOOD_ZERKALO_COM_90000_курсов_на_нашем_форуме!.url")
                    {
                        file.Delete();
                        continue;
                    }

                    var newPath = Path.Combine(file.DirectoryName, file.Name.Replace(watermark, ""));
                    if (newPath != file.FullName)
                        file.MoveTo(newPath);
                }

                var series = AddOrUpdateVideoSeries(author);
                var files = AddSeason(series, folder, courseName, false);

                var notAddedFiles = folder.GetFiles().Select(x => x.FullName).Except(files.Select(x => x.Path)).ToList();

                var fileManager = new FileManager(_db, 
                    new FileManagerSettings(folder.FullName, Path.Combine(config.RootFolder,"Курсы", courseName), true));
                var newFilePath = "";
                foreach (var file in files)
                    newFilePath = (await fileManager.MoveFile(file)).NewPath;

                if (!string.IsNullOrEmpty(newFilePath))
                {
                    var newDirectory = new FileInfo(newFilePath).DirectoryName;
                    foreach (var file in notAddedFiles)
                    {
                        var notMovedFI = new FileInfo(file);
                        var newFileName = Path.Combine(newDirectory, notMovedFI.Name);
                        File.Move(file, newFileName);
                    }
                }
            }
            catch (Exception ex)
            {
                //NLog.LogManager.GetCurrentClassLogger().Error(ex);
            }
        }

    }
}
