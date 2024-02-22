using System;

namespace FileStore.Domain
{
    [Serializable]
    public class AppConfig
    {
        public TelegramSettings TelegramSettings { get; set; }
        public TorrentSettings TorrentSettings { get; set; }
        public Credentials VkontakteSettings { get; set; }

        public int YD_Upload_Threads_Count { get; set; }
        public string RootFolder { get; set; }
        public string RootDownloadFolder { get; set; }

        public static string FFmpegPath
        {
            get
            {
                return @"C:\Dev\_Smth\BookStore-master\lib\ffmpeg\";
            }
        }

        public string YandexToken { get; set; }
    }

    public class TorrentSettings
    {
        public string RP_Pass { get; set; }
        public string RP_Login { get; set; }
        public string QBittorrentPath { get; set; }
        public string QBittorrentWebUI { get; set; }
    }

    public class TelegramSettings
    {
        public string ApiKey { get; set; }
        public long InfoGroupId { get; set; }
        public long AdminId { get; set; }

        public TgCredentials TgCredentials { get; set; }
    }

    [Serializable]
    public class TgCredentials : Credentials
    {
        public TimeSpan WaitForMediaTs { get; set; }
        public TimeSpan WaitTimeForMessageCheck { get; set; }

        public string AppHash { get; set; }
    }

    [Serializable]
    public class Credentials
    {
        public string Password { get; set; }
        public string Login { get; set; }
        public ulong AppId { get; set; }
    }
}
