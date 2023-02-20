using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace Infrastructure
{

    public static class CollectionHelper
    {
        public static bool TryGetKey<K, V>(this IDictionary<K, V> instance, V value, out K key)
        {
            foreach (var entry in instance)
            {
                if (!entry.Value.Equals(value))
                {
                    continue;
                }
                key = entry.Key;
                return true;
            }

            key = default(K);
            return false;
        }
    }

    public static class StringHelper
    {
        public static string ClearEnd(this string text, string end, bool includeEndString = false)
        {
            var indexStart = text.IndexOf(end);

            if (indexStart == -1)
                return text;

            var result = includeEndString ? text.Substring(0, indexStart + end.Length) : text.Substring(0, indexStart);

            return result.Trim();
        }


        /// <summary>
        /// Compute the distance between two strings.
        /// </summary>
        public static int ComputeLevenshteinDistance(this string s, string t)
        {
            if (s == t)
                return 0;

            if (s == null || t == null)
                return 1000;

            int n = s.Length;
            int m = t.Length;
            int[,] d = new int[n + 1, m + 1];

            // Step 1
            if (n == 0)
            {
                return m;
            }

            if (m == 0)
            {
                return n;
            }

            // Step 2
            for (int i = 0; i <= n; d[i, 0] = i++)
            {
            }

            for (int j = 0; j <= m; d[0, j] = j++)
            {
            }

            // Step 3
            for (int i = 1; i <= n; i++)
            {
                //Step 4
                for (int j = 1; j <= m; j++)
                {
                    // Step 5
                    int cost = (t[j - 1] == s[i - 1]) ? 0 : 1;

                    // Step 6
                    d[i, j] = Math.Min(
                        Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1),
                        d[i - 1, j - 1] + cost);
                }
            }
            // Step 7
            return d[n, m];
        }
        public static IEnumerable<string> SplitByNewLine(this string input)
        {
            var lines = input.Split(Environment.NewLine.ToCharArray(), StringSplitOptions.RemoveEmptyEntries).Where(x => !string.IsNullOrWhiteSpace(x));
            return lines;
        }

        public static IEnumerable<string> Split(this string input, string splitter)
        {
            if (string.IsNullOrEmpty(input))
                return new List<string>();

            var lines = input.Split(new string[] { splitter }, StringSplitOptions.RemoveEmptyEntries);
            return lines;
        }

        public static string GetWords(this string str, int number)
        {
            if (string.IsNullOrEmpty(str))
                return str;

            if (number < 1)
                return null;

            var words = str.Split(" ");

            return string.Join(" ", words.Take(number));
        }

        public static IEnumerable<string> Split(this string input, params string[] splitter)
        {
            var lines = input.Split(splitter, StringSplitOptions.RemoveEmptyEntries);
            return lines;
        }

        public static IEnumerable<String> SplitBySize(this String input, Int32 partLength)
        {
            if (input == null)
                throw new ArgumentNullException(nameof(input));
            if (partLength <= 0)
                throw new ArgumentException("Part length has to be positive.", nameof(partLength));

            for (var i = 0; i < input.Length; i += partLength)
                yield return input.Substring(i, Math.Min(partLength, input.Length - i));
        }

        public static IEnumerable<String> SplitByMaxSize(this String input, int maxSize, string separator)
        {
            if (input == null)
                throw new ArgumentNullException(nameof(input));
            if (maxSize <= 0)
                throw new ArgumentException("Part length has to be positive.", nameof(maxSize));
            var result = new List<string>();

            while (input.Length > maxSize)
            {
                var previousPosition = input.IndexOf(separator);
                var position = input.IndexOf(separator);
                do
                {
                    previousPosition = position;
                    position = input.IndexOf(separator, previousPosition + 1);
                } while (position < maxSize && previousPosition != position);

                result.Add(input.Substring(0, previousPosition));
                input = input.Substring(previousPosition);
            }
            result.Add(input);

            return result;
        }

        public static string RemoveNewLines(this string input)
        {
            return input.Replace(Environment.NewLine, " ").Replace("\n", " ");
        }

        public static string TrimEnd(this string input, string suffixToRemove)
        {
            if (input != null && suffixToRemove != null
              && input.EndsWith(suffixToRemove))
            {
                return input.Substring(0, input.Length - suffixToRemove.Length);
            }
            else return input;
        }

        public static IEnumerable<string> GetSubStrings(this string input, string start, string end)
        {
            Regex r = new Regex(Regex.Escape(start) + "(.*?)" + Regex.Escape(end));
            MatchCollection matches = r.Matches(input);
            foreach (Match match in matches)
                yield return match.Groups[1].Value;
        }

        public static IEnumerable<string> ExtractFromString(this string text, string startString, string endString, bool cutPatterns)
        {
            List<string> matched = new List<string>();
            int indexStart = 0, indexEnd = 0;
            bool exit = false;
            while (true)
            {
                indexStart = text.IndexOf(startString);
                var endTagStartIndex = indexStart + startString.Length;
                if (endTagStartIndex > text.Length - 1)
                    break;

                indexEnd = text.IndexOf(endString, endTagStartIndex);
                if (indexStart != -1 && indexEnd != -1)
                {
                    matched.Add(text.Substring(indexStart + (cutPatterns ? startString.Length : 0),
                        indexEnd + (cutPatterns ? 0 : endString.Length) - indexStart - (cutPatterns ? startString.Length : 0)));
                    text = text.Substring(indexEnd + endString.Length);
                }
                else
                    break;
            }
            return matched;
        }

        public static IEnumerable<Tuple<int, int>> ExtractPositionsFromString(this string text, string startString, string endString, bool cutPatterns)
        {
            List<Tuple<int, int>> matched = new List<Tuple<int, int>>();

            if (string.IsNullOrEmpty(text))
                return matched;

            int indexStart = -1, indexEnd = 0;
            bool exit = false;
            while (!exit)
            {
                indexStart = text.IndexOf(startString, indexStart + 1);
                indexEnd = text.IndexOf(endString, indexEnd + 1);
                if (indexStart != -1 && indexEnd != -1)
                {
                    matched.Add(new Tuple<int, int>(indexStart + (cutPatterns ? startString.Length : 0),
                        indexEnd + (cutPatterns ? 0 : endString.Length) - indexStart - (cutPatterns ? startString.Length : 0)));
                    //text = text.Substring(indexEnd + endString.Length);
                }
                else
                    exit = true;
            }
            return matched;
        }

        public static string ClearSpaces(this string tempo, int maxLength = 0)
        {
            if (tempo == null)
                return null;

            tempo = tempo.Trim().Replace(Environment.NewLine, " ");
            tempo = tempo.Replace("\t", " ");
            tempo = tempo.Replace("\n", " ");

            RegexOptions options = RegexOptions.None;
            Regex regex = new Regex("[ ]{2,}", options);
            tempo = regex.Replace(tempo, " ");

            if (maxLength < 1)
                return tempo;
            else
                return tempo.Substring(0, Math.Min(tempo.Length, maxLength));
        }

        public static string ClearNBSP(this string tempo)
        {
            if (tempo == null)
                return null;

            return tempo.Replace("&nbsp;", " ");
        }

        public static string SkipLines(this string str, int linesToSkip)
        {
            string[] lines = str
                .Split(Environment.NewLine.ToCharArray())
                .Skip(linesToSkip)
                .ToArray();

            string output = string.Join(Environment.NewLine, lines);
            return output;
        }

        public static string Between(this string text, int start, int end)
        {
            return text.Substring(start, end - start);
        }

        public static bool OnlyLetters(this string text)
        {
            return text.All(Char.IsLetterOrDigit);
            //return Regex.IsMatch(text, @"^[a-zA-Z]+$");
        }

        public static string OnlyDigits(this string text)
        {
            var digits = text.Where(Char.IsDigit);

            return string.Join("", digits);
        }

        public static string StartingFrom(this string text, string start, bool includeStartString = false)
        {
            var indexStart = text.IndexOf(start);

            if (indexStart == -1)
                return null;

            return includeStartString ? text.Substring(indexStart) : text.Substring(indexStart + start.Length);
        }

        public static string ClearSerieName(this string name)
        {
            return name.Trim().Trim('.').Trim('.').Trim('-').Trim();
        }

        public static string EndingBefore(this string text, string endStr)
        {
            if (string.IsNullOrEmpty(text))
                return text;

            var qualityStart = text.IndexOf(endStr);
            if (qualityStart != -1)
                text = text.Substring(0, qualityStart);

            return text;
        }
    }
}
