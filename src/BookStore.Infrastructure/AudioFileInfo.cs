using System;
using System.Collections.Generic;
using System.Linq;

namespace Infrastructure
{
    public record class AudioFileInfo
    {
        public AudioFileInfo(string bookTitle, string author)
        {
            BookTitle = bookTitle;
            Author = author;
        }

        public AudioFileInfo(string folderName)
        {
            Voice = GetVoice(folderName);

            var removedVoice = !string.IsNullOrEmpty(Voice) ? folderName.Replace(Voice, "") : folderName;
            var authorParts = removedVoice.Split('-', StringSplitOptions.RemoveEmptyEntries);
            if (authorParts.Length > 1)
            {
                BookTitle = ClearString(authorParts.ElementAt(1));
                Author = ClearString(authorParts.First());
            }
            else
                BookTitle = ClearString(authorParts.First());
        }

        public string BookTitle { get; set; }
        public string Author { get; set; }
        public string Voice { get; set; }

        private string ClearString(string name)
        {
            return SplitBySeparators(name).FirstOrDefault().Trim();
        }

        private static string GetVoice(string folderName)
        {
            var voice = "";
            var voiceParts = SplitBySeparators(folderName);
            if (voiceParts.Count() > 1)
            {
                voice = voiceParts.Last();
            }

            return voice;
        }

        private static IEnumerable<string> SplitBySeparators(string folderName)
        {
            return folderName.Split(new string[] { "(", ")", "[", "]", "_", "чит." }, StringSplitOptions.RemoveEmptyEntries).ToList().Select(x => x.Trim());
        }

        internal string ClearFileName(string name)
        {
            return name.Split("##").First()
                    .Replace(".mp3", "").Replace(BookTitle, "").Replace(BookTitle.ToUpper(), "").Replace(Author??"asdasdas", "");
        }
    }
}
