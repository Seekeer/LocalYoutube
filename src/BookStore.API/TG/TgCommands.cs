using API.FilmDownload;
using API.Resources;
using Infrastructure;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

namespace API.TG
{
    public enum CommandType
    {
        [CommandName(TgBot.UPDATECOVER_MESSAGE)]
        FixCover,
        [CommandName(TgBot.SETUP_VLC_Message)]
        SetupVLC,
        [CommandName(TgBot.SUSPEND_PC_Message)]
        SuspendPC,
        [CommandName(TgBot.START_ANYDESK_MESSAGE)]
        StartAnydesk,
        [CommandName(TgBot.STOP_ANYDESK_MESSAGE)]
        StopAnydesk,
        [CommandName(TgBot.SHOW_ALL_SEARCH_RESULT_Message)]
        ShowAllSearchResult,
        [CommandName("updatecover")]
        UpdateCover,
        [CommandName("rename")]
        Rename,
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
        [CommandName("УдалитьРутрекер")]
        DeleteByRutracker,
        [CommandName("Удалить")]
        DeleteById,
        [CommandName("Искусство")]
        Art,
        [CommandName("Аудиосказка")]
        AudioFairyTale,
        AudioBook,
        [CommandName("Аудиокнига")]
        SearchAudioBook,
        [CommandName("Проверить подписки на Youtube")]
        CheckYoutube,
        Unknown,
        DownloadCossacks,
        DownloadPremier,
        DownloadIt,
        [CommandName("СЕ-Мудрец")]
        DownloadKurginyanMudrec,
        [CommandName("СЕ-Другое")]
        DownloadKurginyanOther,
        [CommandName("СВ-Укр")]
        DownloadEotUkr,
        [CommandName("СВ-КП")]
        DownloadEotKP,
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
        public IEnumerable<string> GetDataParts()
        {
            return Data.Split(CommandParser.SEPARATOR);
        }
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
        public static IEnumerable<string> GetCommandName(CommandType command)
        {
            var memberInfos = typeof(CommandType).GetMember(command.ToString());
            var enumValueMemberInfo = memberInfos.FirstOrDefault(m => m.DeclaringType == typeof(CommandType));
            var valueAttributes = enumValueMemberInfo.GetCustomAttributes(typeof(CommandNameAttribute), false);

            if (!valueAttributes.Any())
                return new List<string>(); 

            return ((CommandNameAttribute)valueAttributes[0]).Names;
        }

        public static CommandType ParseCommand(string message)
        {
            try
            {
                message  = message.Trim('/');
                if (string.IsNullOrEmpty(message))
                    return CommandType.Unknown;

                if (message.IndexOf(SEPARATOR) > 0)
                    message = message.ClearEnd(SEPARATOR);

                foreach (var command in (CommandType[])Enum.GetValues(typeof(CommandType)))
                {
                    if (string.Compare(message, command.ToString(), true) == 0)
                        return command;

                    if (message == ((int)command).ToString())
                        return command;

                    var names = GetCommandName(command);
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


        public const string SEPARATOR = ";;";

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
