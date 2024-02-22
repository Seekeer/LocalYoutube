using FFMpegCore;
using FileStore.Domain.Models;
using FileStore.Infrastructure.Context;
using System;
using System.Drawing;
using System.IO;
using System.Linq;

namespace Infrastructure
{
    public static class VideoHelper
    {
        public static string ChangeQuality(string path, string resultFolder, FFMpegCore.Enums.VideoSize size)
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
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
                return "";
            }
        }

        public static string EncodeToMp4(string path, bool encodeAlways = false, string destinationPath = null)
        {
            if (IsEncoded(path) && !encodeAlways)
                return null;

            string resultPath = GetNewPath(destinationPath ?? path);

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

            //FFMpegArguments
            //   .FromPipeInput(new StreamPipeSource(inputStream))
            //   .OutputToPipe(new StreamPipeSink(outputStream), options => options
            //       .WithVideoCodec("vp9")
            //       .WithVariableBitrate(1200)
            //       .ForceFormat("webm"))
            //   .ProcessSynchronously();
            FFMpeg.Convert(path, resultPath, format, FFMpegCore.Enums.Speed.Faster,
                FFMpegCore.Enums.VideoSize.Original, FFMpegCore.Enums.AudioQuality.VeryHigh, true);

            return resultPath;
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

                    videoFile.VideoFileExtendedInfo.SetCover(memoryStream.ToArray());
                }
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex);
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

        public static string GetNewPath(string path)
        {
            var fileInfo = new FileInfo(path);
            var resultPath = path.Replace(fileInfo.Extension, ".mp4");

            resultPath = resultPath.Replace(@"D:\VideoServer\\", @"C:\VideoServer\");
            return resultPath;
        }

        public static bool ShouldConvert(VideoFile file)
        {
            if(file == null)
                return false;

            return (new IsOnlineVideoAttribute()).HasAttribute(file.Type) && !IsEncoded(file.Path);
        }

        public static bool IsEncoded(string path)
        {
            var fileInfo = new FileInfo(path);

            return (fileInfo.Extension == ".mp4" || fileInfo.Extension == ".webm");
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
    }
}