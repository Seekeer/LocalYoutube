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

namespace Infrastructure
{
    public class DbUpdateManager : IDisposable
    {
        private VideoCatalogDbContext _db;
        private Origin _origin;
        private VideoType _type;
        private int _episodeNumber;
        private bool _ignoreNonCyrillic = true;

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

        public void FillSeries(string rootPath, Origin origin, VideoType type, bool severalSeries = true, string seriesName = null)
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

        public void Convert(VideoFile file)
        {
            try
            {
                var oldFile = file.Path;
                var newFilePath = EncodeToMp4(file.Path);

                if (newFilePath == null)
                    return;

                file.Path = newFilePath;
                _db.VideoFiles.Update(file);
                _db.SaveChanges();

                var updatedFile = _db.VideoFiles.FirstOrDefault(x => x.Id == file.Id);

                File.Delete(oldFile);
            }
            catch (Exception ex)
            {
            }
        }

        private void AddSeries(DirectoryInfo dir, string seriesName = null)
        {
            var series = AddOrUpdateVideoSeries(seriesName ?? dir.Name);

            var folders = dir.GetDirectories();

            if (!folders.Any())
                AddSeason(series, dir);
            else
            {
                foreach (var season in folders)
                    AddSeason(series, season);

                AddSeason(series, dir);
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

        public IEnumerable<VideoFile> AddSeason(Series series, DirectoryInfo dir, string seasonName = null)
        {
            var season = AddOrUpdateSeason(series, seasonName ?? dir.Name);

            return AddSeason(series, season, dir);
        }

        private IEnumerable<VideoFile> AddSeason(Series series, Season season, DirectoryInfo dir)
        {
            var result = new List<VideoFile>();
            foreach (var file in dir.EnumerateFiles("", SearchOption.AllDirectories))
                result.Add(AddFile(file, series, season));

            return result;
        }

        private VideoFile AddFile(FileInfo file, Series series, Season season)
        {
            try
            {
                if (IsBadExtension(file))
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
            }

            return null;
        }

        private bool IsBadExtension(FileInfo file)
        {
            //try
            //{
            //    var extension = MimeTypeMap.GetExtension(document.mime_type);

            //}
            //catch (Exception ex)
            //{
            //}

            return file.Name.EndsWith("jpg") || file.Name.EndsWith("jpeg") || file.Name.EndsWith("docx") || file.Name.EndsWith("png") ||
                                file.Name.EndsWith("nfo") || file.Name.EndsWith("mp3") || file.Name.EndsWith("txt") || file.Name.EndsWith("pdf") ||
                                file.Name.EndsWith("xlsx") || file.Name.EndsWith("pdf") || file.Name.EndsWith("zip") || file.Name.EndsWith("vtt") ||
                                file.Name.EndsWith("srt") || file.Name.EndsWith("rar") || file.Name.EndsWith("zip") || file.Name.EndsWith("vtt") ||
                                file.Name.EndsWith("pptx") || file.Name.EndsWith("html") || file.Name.EndsWith("qB") || file.Name.EndsWith("lnk") ||
                                file.Name.EndsWith("mka") || file.Name.EndsWith("ass") || file.Name.EndsWith("tff") || file.Name.EndsWith("ac3") ||
                                file.Name.EndsWith("ogg") ||
                                file.FullName.Contains("Конспект") && _type == VideoType.Courses;
        }

        public void MoveDownloadedToAnotherSeries(VideoType type, string seriesName)
        {
            //var files = _db.VideoFiles.Where(x => x.Type == VideoType.Film).OrderByDescending(x =>x.Id).ToList();
            var files = _db.VideoFiles.Where(x => x.Type == VideoType.Downloaded && !x.IsDownloading ).ToList();
            foreach (var file in files)
            {
                MoveToAnotherSeries(file, type, seriesName);
            }
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

        public void MoveToAnotherSeries(VideoFile file, VideoType type, string seriesName)
        {
            _type = type;

            var series = AddOrUpdateVideoSeries(seriesName);
            var season = AddOrUpdateSeason(series, seriesName);
            //var series = _db.Series.FirstOrDefault(x => x.Type == type);
            //var season = _db.Seasons.FirstOrDefault(x => x.SeriesId == series.Id);

            file.SeriesId = series.Id;
            file.SeasonId = season.Id;
            file.Type = type;

            if ((new IsOnlineVideoAttribute()).HasAttribute(type))
                Convert(file);

            _db.SaveChanges();
        }
        public Season AddOrUpdateSeason(int seriesId, string name)
        {
            var serie = _db.Series.FirstOrDefault(x => x.Id == seriesId);

            return AddOrUpdateSeason(serie, name);
        }

        public Season AddOrUpdateSeason(Series series, string name)
        {
            //var seasons = _db.Seasons.ToList();
            //foreach (var season1 in seasons)
            //{
            //    if (!_db.Files.Any(x => x.SeasonId == season1.Id))
            //    {
            //        _db.Seasons.Remove(season1);
            //    }
            //}

            var season = _db.Seasons.FirstOrDefault(x => x.Name == name);
            if (season == null || season.SeriesId != series.Id)
            {
                season = new Season { Name = name, Series = series };
                _db.Seasons.Add(season);
                _db.SaveChanges();
            }

            return season;
        }

        public Series GetDownloadSeries()
        {
            return AddOrUpdateVideoSeries("Загрузки", false);
        }

        public Series AddOrUpdateVideoSeries(string folderName, bool analyzeFolderName = true, VideoType? type = null)
        {
            if (type == null)
                type = _type;

            var series = AddOrUpdateSeries(folderName, analyzeFolderName, type == VideoType.ChildEpisode || type == VideoType.FairyTale || type == VideoType.Animation);
            series.Type = type;

            _db.SaveChanges();

            return series;
        }

        public Series AddOrUpdateSeries(string folderName, bool analyzeFolderName, bool isChild)
        {
            var name = analyzeFolderName ? GetSeriesNameFromFolder(folderName) : folderName;

            var series = _db.Series.FirstOrDefault(x => x.Name == name);
            if (series == null)
            {
                series = new Series { Name = name, Origin = _origin };
                series.IsChild = isChild;
                _db.Series.Add(series);
            }

            return series;
        }

        public static string GetSeriesNameFromFolder(string name)
        {
            var result = "";
            var index =0;
            string pattern = @"\p{IsCyrillic}";
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
            name = name.Replace("_", " ").Replace("1080p.m4v", " ").Replace("HD", " ").Replace("720p", " ");

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

        public void AddFromYoutube(VideoFile file, string seasonName, bool watchLater)
        {
            var series = AddOrUpdateVideoSeries("Youtube", false);
            series.Type = VideoType.Youtube;
            var season = watchLater ? AddOrUpdateSeason(series, "На один раз с ютуба") : AddOrUpdateSeason(series, seasonName);

            file.Season = season;
            file.Series = series;
            file.Type = VideoType.Youtube;

            _db.SaveChanges();
        }

        public void YoutubeFinished(VideoFile file)
        {
            _db.Files.Add(file);
            _db.SaveChanges();
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
            video.Name = GetEpisodeNameFromFilenName(file.Name);
            video.Path = file.FullName;
            video.Type = _type;
            video.Origin = _origin;
            video.Series = series;
            video.Season = season;
            video.Number = _episodeNumber++;

            if (_type == VideoType.ChildEpisode)
            {
                video.Number = GetSeriesNumberFromName(file.Name);
            }

            FillVideoProperties(video);

            return video;
        }

        public static bool IsEncoded(string path)
        {
            var fileInfo = new FileInfo(path);

            return (fileInfo.Extension == ".mp4" || fileInfo.Extension == ".webm");
        }

        public static string EncodeToMp4(string path)
        {
            if (IsEncoded(path))
                return null;

            var fileInfo = new FileInfo(path);

            var resultPath = path.Replace(fileInfo.Extension, ".mp4");

            if (File.Exists(resultPath))
                return resultPath;

            var format = FFMpeg.GetContainerFormat("mp4");

            //FFMpegArguments
            //    .FromFileInput(path)
            //    .OutputToFile(resultPath, false, options => options
            //        .WithVideoCodec("libx264")
            //        //.WithConstantRateFactor(21)
            //        .WithAudioCodec(FFMpegCore.Enums.AudioCodec.Aac)
            //        //.WithVariableBitrate(4)
            //        .UsingMultithreading(true)
            //        //.WithVideoFilters(filterOptions => filterOptions
            //        //    .Scale(VideoSize.Hd))
            //        .WithFastStart())
            //    .ProcessSynchronously();

            //await FFMpegArguments
            //    .FromPipeInput(new StreamPipeSource(inputStream))
            //    .OutputToPipe(new StreamPipeSink(outputStream), options => options
            //        .WithVideoCodec("vp9")
            //        .ForceFormat("webm"))
            //    .ProcessAsynchronously();
            FFMpeg.Convert(path, resultPath, format, FFMpegCore.Enums.Speed.Faster,
                FFMpegCore.Enums.VideoSize.Original, FFMpegCore.Enums.AudioQuality.VeryHigh, true);

            return resultPath;
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

        public static string EncodeFile(string path, string resultFolder, FFMpegCore.Enums.VideoSize size)
        {
            try
            {
                Directory.CreateDirectory(resultFolder);
                var fileInfo = new FileInfo(path);
                //var resultPath = Path.Combine(resultFolder, fileInfo.Name.Replace(fileInfo.Extension, ".mp4"));
                //var format = FFMpeg.GetContainerFormat("mp4");
                //FFMpeg.Convert(path, resultPath, format, FFMpegCore.Enums.Speed.Medium,
                //    size, FFMpegCore.Enums.AudioQuality.Normal, true);

                var resultPath = Path.Combine(resultFolder, fileInfo.Name.Replace(fileInfo.Extension, ".mkv"));
                FFMpegArguments
                    .FromFileInput(path)
                    .OutputToFile(resultPath, false, options => options
                        .WithVideoCodec(FFMpegCore.Enums.VideoCodec.LibX264)
                        .WithConstantRateFactor(28)
                        .WithAudioCodec(FFMpegCore.Enums.AudioCodec.Aac)
                        .WithVariableBitrate(4)
                        .UsingMultithreading(true)
                        .WithVideoFilters(filterOptions => filterOptions
                        .Scale(FFMpegCore.Enums.VideoSize.Hd))
                        .WithFastStart())
                        .ProcessSynchronously();

                //format = FFMpeg.GetContainerFormat("mkv");
                //FFMpeg.Convert(path, resultPath, format, FFMpegCore.Enums.Speed.Medium,
                //    size, FFMpegCore.Enums.AudioQuality.Normal, true);

                //resultPath = Path.Combine(resultFolder, fileInfo.Name.Replace(fileInfo.Extension, "sf.mp4"));
                //format = FFMpeg.GetContainerFormat("mp4");
                //FFMpeg.Convert(path, resultPath, format, FFMpegCore.Enums.Speed.SuperFast,
                //    size, FFMpegCore.Enums.AudioQuality.Normal, true);

                //resultPath = Path.Combine(resultFolder, fileInfo.Name.Replace(fileInfo.Extension, "sf.mkv"));
                //format = FFMpeg.GetContainerFormat("mkv");
                //FFMpeg.Convert(path, resultPath, format, FFMpegCore.Enums.Speed.SuperFast,
                //    size, FFMpegCore.Enums.AudioQuality.Normal, true);

                return resultPath;
            }
            catch (Exception ex)
            {
                return "";
            }
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

        public static void FillVideoProperties(VideoFile videoFile)
        {
            
            try
            {
                var probe = FFProbe.Analyse(videoFile.Path);
                videoFile.Duration = probe.Duration;

                var bitmap = videoFile.Duration.TotalSeconds > 65 ?
                    videoFile.Duration.TotalMinutes > 10 ? 
                        FFMpeg.Snapshot(videoFile.Path, null, TimeSpan.FromMinutes(4)) :
                        FFMpeg.Snapshot(videoFile.Path, null, TimeSpan.FromMinutes(1)) :
                    FFMpeg.Snapshot(videoFile.Path, null, TimeSpan.FromSeconds(2));
                videoFile.Quality = DetectQuality(bitmap);

                using (MemoryStream memoryStream = new MemoryStream())
                {
                    bitmap.Save(memoryStream, System.Drawing.Imaging.ImageFormat.Jpeg);

                    videoFile.VideoFileExtendedInfo.Cover = memoryStream.ToArray();
                }
            }
            catch (Exception ex)
            {
            }

            //var objMediaInfo = new MediaInfo.MediaInfo();

            //objMediaInfo.Open(@"TheFullPathOf\test.mp4");
            //string result = objMediaInfo.Inform();
            //string duration = objMediaInfo.Option("Duration");
            //objMediaInfo.Close();

            //return File.ReadAllBytes(@"C:\Dev\_Smth\BookStore-master\src\BookStore.Infrastructure\bin\Debug\netcoreapp3.1\photo_2021-12-10_10-47-35.jpg");
            //var inputFile = new MediaFile { Filename = file.FullName };
            //var outputFile = new MediaFile { Filename = @"temp.jpg" };

            //using (var engine = new Engine())
            //{
            //    engine.GetMetadata(inputFile);

            //    // Saves the frame located on the 15th second of the video.
            //    var options = new ConversionOptions { Seek = TimeSpan.FromSeconds(65) };
            //    engine.GetThumbnail(inputFile, outputFile, options);
            //}

            //return File.ReadAllBytes(outputFile.Filename);
        }

        private static Quality DetectQuality(Bitmap bitmap)
        {
            switch (bitmap.Height)
            {
                case 1080:
                    return Quality.FullHD;
                case 720:
                    return Quality.HD;
                default:
                    return Quality.Unknown;
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

        public IEnumerable<VideoFile> UpdateDownloading(Func<VideoFile, bool> selectFiles, int? newSeasonId = null)
        {
            var ready = new List<VideoFile>();
            IEnumerable<VideoFile> queue = _db.VideoFiles
                .Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).Include(x => x.Series).Include(x => x.Season)
                .Where(selectFiles).ToList();

            _ignoreNonCyrillic = true;
            ready.AddRange(UpdateEpisodes(queue, VideoType.ChildEpisode));
            queue = queue.Except(ready);
            _ignoreNonCyrillic = false;
            ready.AddRange(UpdateFiles(queue));
            queue = queue.Except(ready);
            ready.AddRange(UpdateEpisodes(queue, VideoType.AdultEpisode));
            queue = queue.Except(ready);

            var online = ready.Where(x => (new IsOnlineVideoAttribute()).HasAttribute(x.Type));
            
            foreach (var item in online)
                Convert(item);

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
                    if (info.IsDownloading && !IsBadExtension(file))
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
                    FillVideoProperties(addedFile);
                    result.Add(addedFile);
                }

            }

            _db.SaveChanges();

            return result;
        }

        private IEnumerable<VideoFile> UpdateFiles(IEnumerable<VideoFile> files, int? newSeasonId = null)
        {
            var result = new List<VideoFile>();

            foreach (var info in files.Where(x => x.Type != VideoType.Youtube))
            {
                try
                {
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
                    if (dirDirectories.Any(x => x.Name == "VIDEO_TS") || dirFiles.Any(x => x.Name.Contains("VIDEO_TS")))
                        // TODO - message about wrong format
                        continue;

                    if (!dirFiles.Any() || dirFiles.Any(x => x.FullName.EndsWith(".!qB")))
                        continue;

                    dirFiles = dirFiles.Where(x => !IsBadExtension(x));

                    if(dirFiles.Count() > 1)
                    {
                        var moreFilesAdded = false;
                        var twoBiggest = dirFiles.OrderByDescending(x => x.Length).Take(2);

                        ResetUpdateManager(info);

                        if (info.Type == VideoType.Art)
                        {
                            _type = info.Type;
                            var newFiles = AddSeason(info.SeriesId, dir, info.Name);
                            newFiles.ToList().ForEach(x => x.VideoFileExtendedInfo.Cover = info.Cover);
                            result.AddRange(newFiles);
                            moreFilesAdded = true;
                        }
                        // Check that files ~ same size => they are series.
                        else if (twoBiggest.First().Length / twoBiggest.Last().Length > 0.7)
                        {
                            if(info.Type == VideoType.FairyTale)
                                result.AddRange(AddSeason(info.Series, info.Season, dir));
                            else
                                result.AddRange(AddSeason(AddOrUpdateVideoSeries("Многосерийные фильмы"), dir, info.Name));
                            moreFilesAdded = true;
                        }

                        if (moreFilesAdded)
                        {
                            RemoveFileCompletely(info);
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
                }
            }

            _db.SaveChanges();

            return result;
        }

        private void ResetUpdateManager(VideoFile info)
        {
            _type = info.Type;
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
            var files = _db.Files.Where(x => x.SeriesId == seriesId).Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileExtendedInfo);
            foreach (var file in files)
            {
                RemoveFileCompletely(file);
            }

            var seasons = _db.Seasons.Where(x => x.SeriesId == seriesId);
            _db.Seasons.RemoveRange(seasons);

            var serie = _db.Series.FirstOrDefault(x => x.Id == seriesId);
            _db.Series.Remove(serie);
            _db.SaveChanges();
        }

        public void DeleteFiles(int startId, int endId, bool removeFile = true)
        {
            var files = _db.Files.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfos).Where(x => x.Id >= startId && x.Id <= endId).ToList();

            foreach (var file in files)
            {
                DeleteFile(removeFile, file);
            }
        }

        public void DeleteFile(bool removeFile, DbFile file)
        {
            if (removeFile && System.IO.File.Exists(file.Path))
                System.IO.File.Delete(file.Path);

            RemoveFileCompletely(file);

            _db.SaveChanges();
        }

        public void RemoveFileCompletely(DbFile file)
        {
            file.VideoFileUserInfos.ToList().ForEach(x => _db.FilesUserInfo.Remove(x));
            _db.FilesInfo.Remove(file.VideoFileExtendedInfo);
            _db.Files.Remove(file);
        }

        public void UpdateAudioInfo(AudioFile audioFile)
        {
            using (var mp3 = new Mp3(audioFile.Path))
            {
                Id3Tag tag = mp3.GetTag(Id3TagFamily.Version2X);

                audioFile.Name = tag?.Title ?? audioFile.Name;
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

        public void AddAudioFilesFromTg(string text, IEnumerable<string> enumerable, AudioType type, Origin origin, string coverImage)
        {
            var rows = text.SplitByNewLine().ToList();

            var artistName = rows.Count > 0 ? rows[0] : "Аудио";
            var albumName = rows.Count > 1 ? rows[1] : "Неизвестный";

            var isChild = type == AudioType.FairyTale;
            var artist = AddOrUpdateSeries(artistName, false, isChild);
            artist.AudioType = type;

            var album = AddOrUpdateSeason(artist, albumName);

            var files = new List<AudioFile>();
            foreach (var item in enumerable.Select((path, index) => (path, index)))
            {
                var fInfo = new FileInfo(item.path);

                var filename = fInfo.Name.Split("##").First().Replace(".mp3","");

                var audioFile = new AudioFile
                {
                    Season = album,
                    Series = artist,
                    Path = item.path,
                    Name = filename,
                    Number = item.index + 1,
                    Type = type,
                    Origin = origin,
                };

                UpdateAudioInfo(audioFile);
                files.Add(audioFile);
            }

            var start = new string[] { "Читает", "В ролях", "Исполнители", "Рассказчик" };
            var voice = rows.FirstOrDefault(x => start.Any(y => x.Contains(y)));
            if (voice != null)
            {
                start.ToList().ForEach(x => voice = voice.Replace(x, ""));
                voice.Trim(' ', '-', ':', '.');

                files.ForEach(x => x.VideoFileExtendedInfo.Director = voice);
            }

            if (!string.IsNullOrEmpty(coverImage))
            {
                var file = files.First();

                file.VideoFileExtendedInfo.Cover = File.ReadAllBytes(coverImage);
            }

            _db.AudioFiles.AddRange(files);
            _db.SaveChanges();
        }

        public void Dispose()
        {
            _db.Dispose();
        }
    }
}
