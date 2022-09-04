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

namespace Infrastructure
{
    public class DbUpdateManager
    {
        private VideoCatalogDbContext _db;
        private Origin _origin;
        private VideoType _type;
        private int _episodeNumber;

        static DbUpdateManager()
        {
            //FFmpegDownloader.GetLatestVersion(FFmpegVersion.Official);
            GlobalFFOptions.Configure(new FFOptions { BinaryFolder = @"C:\Dev\_Smth\BookStore-master\lib\ffmpeg\" });
                FFmpeg.SetExecutablesPath(@"C:\Dev\_Smth\BookStore-master\lib\ffmpeg\");
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
            var series = AddOrUpdateSeries(dirInfo.Name);

            AddSeason(series, dirInfo);

            _db.SaveChanges();
        }

        public void OperaBalley(string operaPath, string balleyPath, Origin origin, VideoType type)
        {
            _origin = origin;
            _type = type;

            var series = AddOrUpdateSeries("Опера и балет");

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
            var oldFile = file.Path;
            var newFilePath = EncodeToMp4(file.Path);

            if (newFilePath == null)
                return;

            file.Path = newFilePath;
            _db.VideoFiles.Update(file);
            _db.SaveChanges();

            var updatedFile = _db.VideoFiles.FirstOrDefault(x => x.Id == file.Id);

            if (updatedFile.Path == newFilePath)
                File.Delete(oldFile);
        }

        private void AddSeries(DirectoryInfo dir, string seriesName = null)
        {
            var series = AddOrUpdateSeries(seriesName ?? dir.Name);

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

        public void AddSeason(int seriesId, string directory)
        {
            var serie = _db.Series.FirstOrDefault(x => x.Id == seriesId);

            AddSeason(serie, new DirectoryInfo(directory));
        }

        public void AddSeason(Series series, DirectoryInfo dir)
        {
            var season = AddOrUpdateSeason(series, dir.Name);

            AddSeason(series, season, dir);
        }

        private void AddSeason(Series series, Season season, DirectoryInfo dir)
        {
            //Parallel.ForEach(dir.EnumerateFiles(), file =>
            foreach (var file in dir.EnumerateFiles("", SearchOption.AllDirectories))
            {
                try
                {
                    if (file.Name.EndsWith("jpg") || file.Name.EndsWith("jpeg") || file.Name.EndsWith("docx") || file.Name.EndsWith("png") || 
                        file.Name.EndsWith("nfo") || file.Name.EndsWith("mp3") || file.Name.EndsWith("txt") || file.Name.EndsWith("pdf") ||
                        file.Name.EndsWith("xlsx") || file.Name.EndsWith("pdf") || file.Name.EndsWith("zip") || file.Name.EndsWith("vtt") ||
                        file.Name.EndsWith("srt") || file.Name.EndsWith("rar") || file.Name.EndsWith("zip") || file.Name.EndsWith("vtt") ||
                        file.Name.EndsWith("pptx") || file.Name.EndsWith("html") || file.FullName.Contains("Конспект") && _type == VideoType.Courses)
                        continue;

                    var existingInfo = _db.VideoFiles.FirstOrDefault(x => x.Path == file.FullName);
                    if (existingInfo != null && existingInfo.SeriesId == series.Id)
                        continue;

                    // TODO - quality
                    VideoFile videoInfo = GetVideoInfo(series, season, file);
                    _db.VideoFiles.Add(videoInfo);

                    _db.SaveChanges();
                }
                catch (Exception ex)
                {
                }
            }
            //);
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

            var series = AddOrUpdateSeries(seriesName);
            var season = AddOrUpdateSeason(series, seriesName);
            //var series = _db.Series.FirstOrDefault(x => x.Type == type);
            //var season = _db.Seasons.FirstOrDefault(x => x.SeriesId == series.Id);

            file.SeriesId = series.Id;
            file.SeasonId = season.Id;
            file.Type = type;

            if (IsOnlineVideoAttribute.HasAttribute(type))
                Convert(file);

            _db.SaveChanges();
        }

        public Season AddOrUpdateSeason(Series series, string name)
        {
            var seasons = _db.Seasons.ToList();
            foreach (var season1 in seasons)
            {
                if (!_db.Files.Any(x => x.SeasonId == season1.Id))
                {
                    _db.Seasons.Remove(season1);
                }
            }

            var season = _db.Seasons.FirstOrDefault(x => x.Name == name);
            if (season == null || season.SeriesId != series.Id)
            {
                season = new Season { Name = name, Series = series };
                _db.Seasons.Add(season);
                _db.SaveChanges();
            }

            return season;
        }

        private Series AddOrUpdateSeries(string folderName, bool analyzeFolderName = true)
        {
            var name = analyzeFolderName ? GetSeriesNameFromFolder(folderName) : folderName;

            var series = _db.Series.FirstOrDefault(x => x.Name == name);
            if (series == null)
            {
                series = new Series { Name = name, Origin = _origin, Type = _type };
                series.IsChild = _type == VideoType.ChildEpisode || _type == VideoType.FairyTale || _type == VideoType.Animation;
                _db.Series.Add(series);
                _db.SaveChanges();
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

        public  string GetEpisodeNameFromFilenName(string name)
        {
            if(_type == VideoType.Courses)
            {
                name = name.Replace("_", " ");

                return name;
            }

            var result = "";
            string pattern = @"\p{IsCyrillic}";
            foreach (var ch in name)
            {
                if (!Regex.IsMatch(ch.ToString(), pattern))
                    if (ch != '-' && ch != '.' && ch != '!' && ch != ',' && !char.IsWhiteSpace(ch))
                        continue;

                result += ch;
            }

            return TrimDots(result);
        }

        public void AddFromYoutube(VideoFile file, string seasonName)
        {
            var series = AddOrUpdateSeries("Youtube", false);
            series.Type = VideoType.Youtube;
            var season = AddOrUpdateSeason(series, seasonName);

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

        private VideoFile GetVideoInfo(Series series, Season season, FileInfo file)
        {
            var videoFile = new VideoFile
            {
                Name = GetEpisodeNameFromFilenName(file.Name),
                Path = file.FullName,
                Type = _type,
                Origin = _origin,
                Series = series,
                Season = season,
                Number = _episodeNumber++
            };

            if(_type == VideoType.ChildEpisode)
            {
                videoFile.Number = GetSeriesNumberFromName(file.Name);
            }

            //FillVideoProperties(videoFile);

            return videoFile;
        }

        public static bool IsEncoded(string path)
        {
            var fileInfo = new FileInfo(path);

            return (fileInfo.Extension == ".mp4");
        }

        private static string EncodeToMp4(string path)
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

                var bitmap = videoFile.Duration.TotalSeconds > 60 ?
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
            var result = new List<VideoFile>();
            var files = _db.VideoFiles.Include(x => x.VideoFileExtendedInfo).Include(x => x.VideoFileUserInfo)
                .Where(selectFiles).ToList();

            foreach (var info in files.Where(x => x.Type != VideoType.Youtube))
            {
                try
                {
                    var dir = new DirectoryInfo(info.Path);

                    if (!dir.Exists)
                    {
                        RemoveFileCompletely(info);
                        continue;
                    }

                    var dirFiles = dir.EnumerateFiles("*", SearchOption.AllDirectories);

                    // Delete file if not exist
                    if (!dirFiles.Any())
                    {
                        RemoveFileCompletely(info);
                        dir.Delete();
                        continue;
                    }

                    if (!dirFiles.Any() || dirFiles.Any(x => x.FullName.EndsWith(".!qB")))
                        continue;

                    var biggestFile = dirFiles.OrderByDescending(x => x.Length).First();

                    info.Path = biggestFile.FullName;
                    info.IsDownloading = false;

                    result.Add(info);

                    if(newSeasonId != null)
                        info.SeasonId = newSeasonId.Value;
                }
                catch (System.Exception ex)
                {
                }
            }

            _db.SaveChanges();

            return result;
        }

        public void FillByRutrackerDownload(string path)
        {
            var dir = new DirectoryInfo(path);
            var folders = dir.EnumerateDirectories().OrderBy(x => x.CreationTime);

            var series = AddOrUpdateSeries("Загрузки", false);
            var season = AddOrUpdateSeason(series, "Rutracker");

            foreach (var folder in folders)
            {
                var dirFiles = folder.EnumerateFiles("*", SearchOption.AllDirectories);

                if (!dirFiles.Any())
                {
                    Directory.Delete(folder.FullName);
                    continue;
                }
                var biggestFile = dirFiles.OrderByDescending(x => x.Length).First();

                var videoFile = new VideoFile
                {
                    Name = GetEpisodeNameFromFilenName(biggestFile.Name),
                    Path = biggestFile.FullName,
                    Type = VideoType.Film,
                    Origin = Origin.Unknown,
                    Series = series,
                    Season = season,
                };

                videoFile.VideoFileExtendedInfo = new FileExtendedInfo()
                {
                    RutrackerId = int.Parse(folder.Name)
                };

                _db.VideoFiles.Add(videoFile);
                _db.SaveChanges();
            }
        }

        public void UpdateChildRutracker(string path)
        {
            var series = AddOrUpdateSeries("Загрузки", false);

            var childDownloaded = AddOrUpdateSeason(series, "Детские мультики");
            var child = _db.VideoFiles.Include(x => x.VideoFileUserInfo).Include(x => x.VideoFileExtendedInfo).Where(x => x.Id >= 3533 && x.Id <= 3553).ToList();
            child.AddRange(_db.VideoFiles.Include(x => x.VideoFileUserInfo).Include(x => x.VideoFileExtendedInfo).Where(x => x.Id >= 3530 && x.Id <= 3530));
            child.AddRange(_db.VideoFiles.Include(x => x.VideoFileUserInfo).Include(x => x.VideoFileExtendedInfo).Where(x => x.Id >= 3565 && x.Id <= 3565));
            foreach (var item in child)
            {
                item.Type = VideoType.Animation;
                item.Season = childDownloaded;
                _db.SaveChanges();
            }
        }

        public void RemoveFileCompletely(DbFile file)
        {
            _db.FilesUserInfo.Remove(file.VideoFileUserInfo);
            _db.FilesInfo.Remove(file.VideoFileExtendedInfo);
            _db.Files.Remove(file);
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
    }
}
