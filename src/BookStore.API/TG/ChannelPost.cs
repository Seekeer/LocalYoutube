using MimeTypes;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.Serialization;
using System.Text;
using System.Threading.Tasks;
using TL;

namespace API.TG
{

    public class ChannelPost
    {
        public ChannelPost(Message channelPost)
        {
            OriginalTgChannelPost = channelPost;
        }

        public string Text { get; set; }
        public List<Attach> Attaches { get; } = new List<Attach>();
        public ChannelPost ForwardedPost { get; set; }

        public bool IsForwarded()
        {
            return !string.IsNullOrEmpty(SourceChannelName);
        }

        public int Id { get; set; }
        public string ChannelName { get; set; }
        public string SourceChannelName { get; set; }
        public DateTime Date { get; set; }
        public string PostLink
        {
            get
            {
                return $"https://t.me/c/{OriginalTgChannelPost.peer_id.ID}/{OriginalTgChannelPost.ID}";
            }
        }
        public Message OriginalTgChannelPost { get; }
        public long MessageGroupId { get; set; }
    }

    public class Attach
    {
        private long _chatId;
        private string _rootDownloadFolder;

        public Attach(TL.Peer peer_id, string rootDownloadFolder)
        {
            this._chatId = peer_id.ID;
            _rootDownloadFolder = rootDownloadFolder;
        }

        public string FilePath { get; private set; }
        public AttachType Type { get; set; }
        public string Url { get; internal set; }
        public bool IsLoading { get; internal set; }

        internal void SetLink(string link)
        {
            Url = (!Uri.IsWellFormedUriString(link, UriKind.Absolute)) ?
                $"https://{link}" : link;
            this.Type = AttachType.Link;
        }

        internal void SetDocumentPath(TL.Document document)
        {
            var extension = "";

            try
            {
                if (document.mime_type == "audio/ogg")
                {
                    this.Type = AttachType.Audio;
                    extension = "ogg";
                }
                if (document.mime_type == "audio/flac")
                {
                    this.Type = AttachType.Audio;
                    extension = "flac";
                }
                else if (document.mime_type == "image/heif")
                {
                    this.Type = AttachType.File;
                    extension = "heif";
                }
                else if (document.mime_type == "application/x-tgsticker")
                {
                    this.Type = AttachType.File;
                    extension = "stick";
                }
                else if (document.mime_type == "image/vnd.djvu+multipage")
                {
                    this.Type = AttachType.File;
                    extension = "djvu";
                }
                else
                {
                    extension = MimeTypeMap.GetExtension(document.mime_type);

                    if (document.mime_type.Contains("video"))
                        this.Type = AttachType.Video;
                    else if (document.mime_type.Contains("image"))
                        this.Type = AttachType.Photo;
                    else if (document.mime_type.Contains("audio"))
                        this.Type = AttachType.Audio;
                    else
                        this.Type = AttachType.File;
                }
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex, $"Проблема с сохранением аттача {document.mime_type}");

                var parts = document.mime_type.Split('/');
                extension = parts.Last();
                this.Type = AttachType.File;
            }

            SetFilePath($"{document.Filename}##{document.id}.{extension}");
        }

        internal void SetPhotoPath(TL.Photo photo)
        {
            this.SetFilePath($"{photo.id}.jpg");
            this.Type = AttachType.Photo;
        }

        private void SetFilePath(string fileName)
        {
            var dir = Path.Combine(_rootDownloadFolder, _chatId.ToString());
            Directory.CreateDirectory(dir);

            FilePath = Path.Combine(dir, $"{fileName}");
        }
    }

    public enum AttachType
    {
        Photo,
        Video,
        Link,
        Audio,
        File
    }
}
