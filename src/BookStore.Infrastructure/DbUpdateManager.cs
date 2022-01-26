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
//using MediaToolkit.Model;
//using MediaToolkit;
//using MediaToolkit.Options;

namespace Infrastructure
{
    public class DbUpdateManager
    {
        private VideoCatalogDbContext _db;
        private Origin _origin;
        private VideoType _type;

        static DbUpdateManager()
        {
            GlobalFFOptions.Configure(new FFOptions { BinaryFolder = @"C:\Dev\_Smth\BookStore-master\src\BookStore.API\bin\Debug\netcoreapp3.1\ffmpeg\" });
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

        public void FillSeries(string rootPath, Origin origin, VideoType type)
        {
            _origin = origin;
            _type = type;

            var dirInfo = new DirectoryInfo(rootPath);
            foreach (var dir in dirInfo.GetDirectories())
            {
                AddSeries(dir);
            }

            _db.SaveChanges();
        }

        public void Convert(VideoFile file)
        {
            var newFilePath = Encode(file.Path);

            if (newFilePath == null)
                return;

            file.Path = newFilePath;
            _db.Files.Update(file);
            _db.SaveChanges();

            var updatedFile = _db.Files.FirstOrDefault(x => x.Id == file.Id);
        }

        private void AddSeries(DirectoryInfo dir)
        {
            var series = AddOrUpdateSeries(dir.Name);

            var folders = dir.GetDirectories();
            //if (!folders.Any())
            //    AddSeason(series, dir);
            //else
            //{
                foreach (var season in folders)
                    AddSeason(series, season);

                AddSeason(series, dir);
            //}
        }

        private void AddSeason(Series series, DirectoryInfo dir)
        {
            var season = AddOrUpdateSeason(series, dir.Name);

            //Parallel.ForEach(dir.EnumerateFiles(), file =>
            foreach (var file in dir.EnumerateFiles())
            {
                try
                {

                    if (file.Name.EndsWith("jpg") || file.Name.EndsWith("jpeg") || file.Name.EndsWith("nfo") || file.Name.EndsWith("mp3"))
                        return;

                    // TODO - quality
                    VideoFile videoInfo = GetVideoInfo(series, season, file);
                    _db.Files.Add(videoInfo);

                    _db.SaveChanges();
                }
                catch (Exception ex)
                {
                }
            }
            //);
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
                series = new Series { Name = name };
                _db.Series.Add(series);
                _db.SaveChanges();
            }

            return series;
        }

        public static string GetSeriesNameFromFolder(string name)
        {
            var index =0;
            string pattern = @"\p{IsCyrillic}";
            do
            {
                var ch = name[index];
                if (!Regex.IsMatch(ch.ToString(), pattern))
                    if (ch != '-' && ch != '.' && ch != '!' && ch != ',' && !char.IsWhiteSpace(ch))
                        break;

                index++;
            } while (index < name.Length);

            return name.Substring(0, index).Trim().TrimEnd('.');
        }

        public static string GetSeriesNameFromFilenName(string name)
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
            return result.Trim().Trim('.').Trim();
        }

        private VideoFile GetVideoInfo(Series series, Season season, FileInfo file)
        {
            var videoFile = new VideoFile
            {
                Name = GetSeriesNameFromFilenName(file.Name),
                Path = file.FullName,
                Type = _type,
                Origin = _origin,
                Series = series,
                Season = season
            };

            if(_type == VideoType.Episode)
            {
                videoFile.Number = GetSeriesNumberFromName(file.Name);
            }

            FillVideoProperties(videoFile);

            return videoFile;
        }

        public static string Encode(string path)
        {
            //return @"D:\Мульты\YandexDisk\Анюта\Советские мультфильмы\Известные\06 - Мой Додыр 1954.mp4";
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

        private void FillVideoProperties(VideoFile videoFile)
        {
            try
            {
                var bitmap = FFMpeg.Snapshot(videoFile.Path, null, TimeSpan.FromMinutes(1));
                videoFile.Quality = DetectQuality(bitmap);

                using (MemoryStream memoryStream = new MemoryStream())
                {
                    bitmap.Save(memoryStream, System.Drawing.Imaging.ImageFormat.Jpeg);

                    videoFile.VideoFileExtendedInfo = new VideoFileExtendedInfo();
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
