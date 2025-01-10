using FileStore.API.Controllers;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Net.Http;
using System.Net;
using System;
using System.Threading.Tasks;
using System.IO;
using System.Xml.Linq;
using System.Xml;
using System.ServiceModel.Syndication;
using System.Linq;
using Polly;
using System.Text;

namespace API.Controllers
{
    [EnableCors("CorsPolicy")]
    [AllowAnonymous]
    [Route("api/[controller]")]
    public class WebhookController : MainController
    {
        [HttpGet]
        [HttpPost]
        [Route("youtubeupdate")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<IActionResult> YoutubeUpdate()
        {
            NLog.LogManager.GetCurrentClassLogger().Info($"WebhookController content");
            try
            {

                string challenge = Request.Query["hub.challenge"];

                //Incoming Notification from Youtube
                if (string.IsNullOrEmpty(challenge))

                {
                    StreamReader reader = new StreamReader(Request.Body);
                    string text = await reader.ReadToEndAsync();
                    var data = ConvertAtomToSyndication(text);
                }
                else
                {
                    new HttpResponseMessage(HttpStatusCode.OK)
                    {
                        Content = new StringContent(challenge),
                        ReasonPhrase = challenge,
                        StatusCode = HttpStatusCode.OK
                    };
                }
            }
            catch (Exception ex)
            {
                //Handle Exception Accordingly.
            }

            return Ok();
        }
        private YoutubeNotification ConvertAtomToSyndication(string text)
        {
            using (var xmlReader = XmlReader.Create(text))
            {
                SyndicationFeed feed = SyndicationFeed.Load(xmlReader);
                var item = feed.Items.FirstOrDefault();
                return new YoutubeNotification()
                {
                    ChannelId = GetElementExtensionValueByOuterName(item, "channelId"),
                    VideoId = GetElementExtensionValueByOuterName(item, "videoId"),
                    Title = item.Title.Text,
                    Published = item.PublishDate.ToString("dd/MM/yyyy"),
                    Updated = item.LastUpdatedTime.ToString("dd/MM/yyyy")
                };
            }
        }

        private string GetElementExtensionValueByOuterName(SyndicationItem item, string outerName)
        {
            if (item.ElementExtensions.All(x => x.OuterName != outerName)) return null;
            return item.ElementExtensions.Single(x => x.OuterName == outerName).GetObject<XElement>().Value;
        }
    }
    public class YoutubeNotification
    {
        public string Id { get; set; }
        public string VideoId { get; set; }
        public string ChannelId { get; set; }
        public string Title { get; set; }
        public string Link { get; set; }
        public Author Author { get; set; }
        public string Published { get; set; }
        public string Updated { get; set; }
        public bool IsNewVideo
        {
            get
            {
                return Published == Updated && !string.IsNullOrEmpty(Published);
            }
        }
    }

    public class Author
    {
        public string Name { get; set; }
        public string Uri { get; set; }
    }

}
