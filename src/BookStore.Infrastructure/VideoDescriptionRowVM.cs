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

        public bool IsTimeRow
        {
            get
            {
                return !string.IsNullOrEmpty(Timestamp);
            }
        }

        public string Paragraph { get; }
        public string Timestamp { get; }

        public TimeSpan GetPosition()
        {
            return Timestamp.ParseTS();
        }

        private int CountInstances(string str, string substring)
        {
            return str.Split(substring).Length - 1;
        }

        public static IEnumerable<VideoDescriptionRowVM> ParseDescription(string description, bool onlyTimestamps)
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
                else if (onlyTimestamps)
                    return new VideoDescriptionRowVM(paragraph, null);
                else
                    return null;
            }).Where(x => x != null).ToList();

            return paragraphs;
        }

        public static TimeSpan CalculateClosest(TimeSpan position, IEnumerable<VideoDescriptionRowVM> description)
        {
            var timeLine = description.Select(x => x.GetPosition()).Order().ToList();
            var index = 0;
            while (index < timeLine.Count)
            {
                if (timeLine[index] > position)
                    return timeLine[index];

                index++;
            }

            return TimeSpan.Zero;
        }
    }
}