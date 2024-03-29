using API.FilmDownload;
using Infrastructure;
using System;
using System.Linq;

namespace API.TG
{
    public enum CommandType
    {
        [CommandName(TgBot.UPDATECOVER_MESSAGE)]
        FixCover,
        [CommandName(TgBot.SETUP_VLC_Message)]
        SetupVLC,
        [CommandName(TgBot.SHOW_ALL_SEARCH_RESULT_Message)]
        ShowAllSearchResult,
        DownloadOneTime,
        DownloadAsDesigned,
        DownloadIndia,
        [CommandName("Сериал")]
        Series,
        [CommandName("Фильм")]
        Film,
        [CommandName("Cartoon")]
        Animation,
        [CommandName("Мульт/с")]
        ChildSeries,
        [CommandName("Сказка")]
        FairyTale,
        [CommandName("Удалить")]
        Delete,
        [CommandName("Искусство")]
        Art,
        [CommandName("Аудиосказка")]
        AudioFairyTale,
        Unknown,
    }

    public class TgCommand
    {
        public TgCommand(string data, CommandType type)
        {
            Data = data;
            Type = type;
        }

        public override string ToString()
        {
            return CommandParser.GetMessageFromData(Type, Data);
        }

        public string Data { get; set; }
        public CommandType Type { get; set; }
    }

    [AttributeUsage(AttributeTargets.Field, AllowMultiple = false, Inherited = true)]
    public class CommandNameAttribute : Attribute
    {
        public CommandNameAttribute(params string[] args)
        {
            Names = args;
        }

        public string[] Names { get; }
    }

    public class CommandParser
    {
        public static CommandType ParseCommand(string message)
        {
            try
            {
                if (string.IsNullOrEmpty(message))
                    return CommandType.Unknown;

                if (message.IndexOf(SEPARATOR) > 0)
                    message = message.ClearEnd(SEPARATOR);

                foreach (var command in (CommandType[])Enum.GetValues(typeof(CommandType)))
                {
                    if (message == ((int)command).ToString())
                        return command;

                    var memberInfos = typeof(CommandType).GetMember(command.ToString());
                    var enumValueMemberInfo = memberInfos.FirstOrDefault(m => m.DeclaringType == typeof(CommandType));
                    var valueAttributes = enumValueMemberInfo.GetCustomAttributes(typeof(CommandNameAttribute), false);

                    if (!valueAttributes.Any())
                        continue;

                    var names = ((CommandNameAttribute)valueAttributes[0]).Names;

                    if (names.Any(x => string.Compare(x, message, StringComparison.OrdinalIgnoreCase) == 0))
                        return command;
                }
            }
            catch (Exception ex)
            {
                NLog.LogManager.GetCurrentClassLogger().Error(ex); ;
            }

            return CommandType.Unknown;
        }

        private const string SEPARATOR = ";;";

        internal static TgCommand GetDataFromMessage(string text)
        {
            var type = ParseCommand(text);

            var data = GetDataFromMessage(text, type);

            return new TgCommand(data, type);
        }

        internal static string GetDataFromMessage(string text, CommandType command)
        {
            return text.Replace((int)command + SEPARATOR, "");
        }

        internal static string GetMessageFromData(CommandType addUkraineNews, string data)
        {
            return (int)addUkraineNews + SEPARATOR + data;
        }
    }

    public static class EnumHelper
    {
        public static string GetDescription<T>(this T enumValue)
            where T : struct, IConvertible
        {
            if (!typeof(T).IsEnum)
                return null;

            var description = enumValue.ToString();
            var fieldInfo = enumValue.GetType().GetField(enumValue.ToString());

            if (fieldInfo != null)
            {
                var attrs = fieldInfo.GetCustomAttributes(typeof(CommandNameAttribute), true);
                if (attrs != null && attrs.Length > 0)
                {
                    description = ((CommandNameAttribute)attrs[0]).Names.First();
                }
            }

            return description;
        }
    }
}
