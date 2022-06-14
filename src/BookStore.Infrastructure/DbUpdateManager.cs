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

        public bool RemoveFilm(string name = null, int id = 0)
        {
            var info = (string.IsNullOrEmpty(name)) ?
                    _db.Files.FirstOrDefault(x => x.Id == id) :
                    _db.Files.FirstOrDefault(x => x.Name == name);

            if (info == null)
            {
                return false;
            }

            var exinfo = new FileExtendedInfo { Id = info.VideoFileExtendedInfo.Id };
            _db.FilesInfo.Attach(exinfo);
            _db.FilesInfo.Remove(exinfo);

            var exinfo2 = new FileUserInfo { Id = info.VideoFileUserInfo.Id };
            _db.FilesUserInfo.Attach(exinfo2);
            _db.FilesUserInfo.Remove(exinfo2);

            _db.VideoFiles.Remove(info as VideoFile);
            _db.Files.Remove(info);
            _db.SaveChanges();
            return true;
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

        private void AddSeason(Series series, DirectoryInfo dir)
        {
            var season = AddOrUpdateSeason(series, dir.Name);

            //Parallel.ForEach(dir.EnumerateFiles(), file =>
            foreach (var file in dir.EnumerateFiles("", SearchOption.AllDirectories))
            {
                try
                {
                    if (file.Name.EndsWith("jpg") || file.Name.EndsWith("jpeg") || file.Name.EndsWith("docx") || 
                        file.Name.EndsWith("nfo") || file.Name.EndsWith("mp3"))
                        return;

                    var existingInfo = _db.VideoFiles.FirstOrDefault(x => x.Path == file.FullName);
                    if (existingInfo != null)
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

        public void MoveDownloadedToAnotherSeries(VideoType type)
        {
            //var files = _db.VideoFiles.Where(x => x.Type == VideoType.Film).OrderByDescending(x =>x.Id).ToList();
            var files = _db.VideoFiles.Where(x => x.Type == VideoType.Downloaded && !x.IsDownloading ).ToList();
            foreach (var file in files)
            {
                MoveToAnotherSeries(file, type);
                if (type == VideoType.Film)
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
        }

        public void MoveToAnotherSeries(VideoFile file, VideoType type)
        {
            var series = _db.Series.FirstOrDefault(x => x.Type == type);
            var season = _db.Seasons.FirstOrDefault(x => x.SeriesId == series.Id);

            file.SeriesId = series.Id;
            file.SeasonId = season.Id;
            file.Type = type;

            _db.SaveChanges();
        }

        private Season AddOrUpdateSeason(Series series, string name)
        {
            var season = _db.Seasons.FirstOrDefault(x => x.Name == name);
            if (season == null)
            {
                season = new Season { Name = name, Series = series };
                _db.Seasons.Add(season);
                _db.SaveChanges();
            }

            return season;
        }

        private Series AddOrUpdateSeries(string folderName)
        {
            var name = GetSeriesNameFromFolder(folderName);
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

        public static string GetEpisodeNameFromFilenName(string name)
        {
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

            FillVideoProperties(videoFile);

            return videoFile;
        }

        public static string EncodeToMp4(string path)
        {
            var fileInfo = new FileInfo(path);

            if (fileInfo.Extension == ".mp4")
                return null;

            var resultPath = path.Replace(fileInfo.Extension, ".mp4");

            if (File.Exists(resultPath))
                return resultPath;

            var format = FFMpeg.GetContainerFormat("mp4");
            FFMpeg.Convert(path, resultPath, format, FFMpegCore.Enums.Speed.Medium,
                FFMpegCore.Enums.VideoSize.Original, FFMpegCore.Enums.AudioQuality.Normal, true);

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

            private void FillVideoProperties(VideoFile videoFile)
        {
            try
            {
                var bitmap = FFMpeg.Snapshot(videoFile.Path, null, TimeSpan.FromMinutes(1));
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

            var probe = FFProbe.Analyse(videoFile.Path);
            videoFile.Duration = probe.Duration;

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

        private Quality DetectQuality(Bitmap bitmap)
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
    }
}
