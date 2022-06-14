using System;

namespace FileStore.API
{
    [Serializable]
    public class AppConfig
    {
        public TelegramSettings TelegramSettings { get; set; }

        public string RP_Pass { get; set; }
        public string RP_Login { get; set; }
        public string RootFolder { get; set; }
        public string RootDownloadFolder { get; set; }
    }

    public class TelegramSettings
    {
        public string ApiKey { get; set; }
        public long ChatId { get; set; }
    }
}
