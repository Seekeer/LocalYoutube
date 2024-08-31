using Infrastructure;
using System.Collections.Generic;
using System.Linq;
using System;
using System.Text.RegularExpressions;
using System.Globalization;

namespace Infrastructure
{
    public class VideoDescriptionRowVM
    {
        public VideoDescriptionRowVM(string paragraph, string value)
        {
            Paragraph = paragraph;
            Timestamp = value;
        }

        public string Paragraph { get; }
        public string Timestamp { get; }

        public TimeSpan GetPosition()
        {
            if (string.IsNullOrEmpty(Timestamp))
                return TimeSpan.Zero;

            var ts = TimeSpan.ParseExact(Timestamp, new string[] { "h\\:mm\\:ss", "mm\\:ss" }, CultureInfo.InvariantCulture);
            return ts;
        }

        private int CountInstances(string str, string substring)
        {
            return str.Split(substring).Length - 1;
        }

        public static IEnumerable<VideoDescriptionRowVM> ParseDescription(string description)
        {
            var result = new List<VideoDescriptionRowVM>();
            if (string.IsNullOrEmpty(description))
                return result;

            var paragraphs = description.SplitByNewLine().Select(paragraph =>
            {
                var convertedWords = paragraph.Trim().Split(" ");
                var firstWord = convertedWords[0];
                var match = Regex.Match(firstWord, @"((\d{1,2}:)?[0-5]?\d:[0-5]?\d)");
                if (match.Success)
                    return new VideoDescriptionRowVM(paragraph.Replace(firstWord, ""), match.Value);
                else
                    return new VideoDescriptionRowVM(paragraph, null);

            }).ToList();

            return paragraphs;
        }
    }
}