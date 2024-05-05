using NUnit.Framework;
using API.Controllers;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;

namespace API.Controllers.Tests
{
    [TestFixture()]
    public class RuTrackerUpdaterTests
    {
        [Test()]
        public async Task ParseVideoInfo_Zit()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\Zit.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Ю Гэ, Гун Ли, Бен Ниу, Ксяо Конг, Ден Фэй, Тао Гуо", videoInfo.Artist);
            Assert.AreEqual("Чжан Имоу / Yimou Zhang", videoInfo.Director);
            Assert.AreEqual("Драма", videoInfo.Genres);
            Assert.AreEqual("Жить", videoInfo.Name);
            Assert.AreEqual(new TimeSpan(2, 12, 35), videoInfo.Duration);
            Assert.AreEqual(1994, videoInfo.Year);

            Assert.AreEqual(@"Действие этой семейной саги происходит в Китае в течении трех десятилетий - в 1940-60 гг. Наследник уважаемой в городе семьи, Фу Гуй - заядлый игрок. Злоключания его семьи начинаются с того, что однажды он проигрывает свой дом....Одна из лучших, на мой взгляд, работ Чжана Имоу. С одной стороны - масштабнейшее историческое полотно, может быть, самых страшных лет китайской истории, с другой - тончайший рассказ об обычной семье. И вроде как самые страшные годы, но при этом в фильме нет ни одного плохого человека.Очень грустный и при этом невероятно жизнеутверждающий фильм. После него действительно хочется жить. Мудрый Имоу, сам в те годы прошедший и через ссылку, и через исправительные работы, очень убедительно доказывает - жить на свете стоит, даже если тебя угораздило родиться в интересное время в нескучной стране.", videoInfo.Description);
            Assert.IsNotNull(videoInfo.Cover);
        }

        [Test()]
        public async Task ParseVideoInfo_Svidetel()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\svidetel.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Питер Уир / Peter Weir", videoInfo.Director);
            Assert.AreEqual(@"Девятилетний мальчик становится свидетелем зверского убийства: прямо на его глазах в туалете филадельфийского вокзала два человека безжалостно зарезали молодого мужчину. Оказывается, убитый был тайным агентом отдела по борьбе с наркотиками. Теперь мальчик- единственный свидетель, который может помочь детективу Джону Буку найти преступников.Лица убийц навсегда впечатались в детскую память. И мальчик увидел их снова, когда его привезли для дачи показаний в местный полицейский участок - он увидел фото убийц на доске почета полицейского управления. С этой минуты за маленьким свидетелем и его единственным защитником, инспектором Буком, начинается охота.", videoInfo.Description);
            Assert.IsNotNull(videoInfo.Cover);
        }

        [Test()]
        public async Task ParseVideoInfo_Wind()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\Wind_5937963.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Ветер крепчает", videoInfo.Name);
            Assert.AreEqual("Хаяо Миядзаки", videoInfo.Director);
            Assert.IsTrue(videoInfo.Description.Contains("Мечта о полётах всегда преследовала человека. Вот и "));
            Assert.IsNotNull(videoInfo.Cover);
        }

        [Test()]
        public async Task ParseVideoInfo_Gora()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\Gora.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual(732, videoInfo.Duration.TotalMinutes);
            Assert.AreEqual(@"Сказка — первый и самый древний путь познания мира. «Гора Самоцветов» — это 54 сказки народов России. Каждую серию из цикла «Гора самоцветов» представляют одни и те же слова: «Мы живём в России». Всего несколько добрых слов о каждом народе, а следом — его мудрая и самобытная сказка. Именно такой радостный и светлый мир каждый взрослый мечтает подарить своему ребёнку. Особую окраску мультсборнику придают голоса известных актёров, которые озвучивали эти сказки.", videoInfo.Description);
            Assert.IsNotNull(videoInfo.Cover);
        }

        [Test()]
        public async Task ParseVideoInfo_Bugsy()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\Bugsy.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Барри Левинсон / Barry Levinson", videoInfo.Director);
            Assert.AreEqual(1991, videoInfo.Year);
            Assert.IsTrue(videoInfo.Description.Contains("Он мог войти в мировую историю, но занял почетное место лишь в кровавой истории организованной преступности. Его имя не попало на страницы школьных учебников, но зато красовалось в заголовках криминальной хроники. Бенджамин Сигал по кличке «Багси» — знаменитый гангстер"));
            Assert.IsNotNull(videoInfo.Cover);
        }

        [Test()]
        public async Task ParseVideoInfo_Las()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\las.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Покидая Лас-Вегас", videoInfo.Name);
            Assert.IsNotNull(videoInfo.Cover);
        }

        [Test()]
        public async Task ParseVideoInfo_Jfk()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\jfk.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Оливер Стоун", videoInfo.Director);
        }

        [Test()]
        public async Task ParseVideoInfo_Rapun()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\Rapun.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Рапунцель: Запутанная история", videoInfo.Name);
        }

        [Test()]
        public async Task ParseVideoInfo_Frozen()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\Frozen.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Холодное сердце", videoInfo.Name);
        }


        [Test()]
        public async Task ParseVideoInfo_Witch1_2()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\Witch1-2.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Сезон: 1-2", videoInfo.SeasonName);
        }


        [Test()]
        public async Task ParseVideoInfo_Witch1()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\Witch1.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Сезон: 1", videoInfo.SeasonName);
        }

        [Test()]
        public async Task ParseVideoInfo_Aviator()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\aviator.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Авиатор", videoInfo.Name);
            Assert.AreEqual("драма, биография", videoInfo.Genres);
            //Assert.AreEqual("Мартин Скорсезе", videoInfo.Director);
        }

        [Test()]
        public async Task ParseVideoInfo_Fox()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\MrFox.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.IsNull(videoInfo.Artist);
            Assert.AreEqual(@"Разъяренные фермеры, уставшие от постоянных нападок хитрого лиса на их курятники, готовятся уничтожить своего врага и его «хитрое» семейство.Рип от CtrlHD!", videoInfo.Description);
            Assert.AreEqual("комедия, приключения, семейный", videoInfo.Genres);
            Assert.AreEqual("Бесподобный мистер Фокс", videoInfo.Name);
            Assert.AreEqual(new TimeSpan(1, 26, 44), videoInfo.Duration);
            Assert.AreEqual(2009, videoInfo.Year);

            Assert.IsNotNull(videoInfo.Cover);
            Assert.AreEqual("Уэс Андерсон / Wes Anderson", videoInfo.Director);
        }

        [Test()]
        public async Task ParseVideoInfo_Rainman()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\Rainman.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual(@"Дастин Хоффман, Том Круз, Валерия Голино, Джералд Р. Молен, Джек Мёрдок, Майкл Д. Робертс, Ральф Сеймур, Люсинда Дженни, Бонни Хант, Ким Робиллард", videoInfo.Artist);
            Assert.AreEqual("Барри Левинсон / Barry Levinson", videoInfo.Director);
            Assert.AreEqual("драма", videoInfo.Genres);
            Assert.AreEqual("Человек дождя", videoInfo.Name);
            Assert.AreEqual(new TimeSpan(2, 13, 46), videoInfo.Duration);
            Assert.AreEqual(1988, videoInfo.Year);

            Assert.IsNotNull(videoInfo.Cover);
            Assert.AreEqual(@"У Чарли, грубоватого и эгоистичного молодого повесы, в наследство от отца остались лишь розовые кусты да «Бьюк» 49-го года. Внезапным «сюрпризом» для него стало открытие того, что львиная доля наследства оставлена отцом его больному аутизмом брату Раймонду.", videoInfo.Description);
        }

        [Test()]
        public async Task ParseVideoInfo_Other()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\other.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual(new TimeSpan(1, 49, 0), videoInfo.Duration);

            Assert.IsNotNull(videoInfo.Cover);
        }

        [Test()]
        public async Task ParseVideoInfo_Star()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\stars.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual(new TimeSpan(1, 32, 23), videoInfo.Duration);
        }

        [Test()]
        public async Task ParseVideoInfo_Star1()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\stars1.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual(2014, videoInfo.Year);
        }

        [Test()]
        public async Task ParseVideoInfo_Trud()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\trud.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual(@"Кейт Уинслет, Джош Бролин, Гэттлин Гриффит, Тоби Магуайр, Том Липински, Майка Монро, Кларк Грегг, Джеймс Ван Дер Бик, Дж.К. Симмонс, Брук Смит", videoInfo.Artist);
            Assert.AreEqual("Джейсон Райтман / Jason Reitman", videoInfo.Director);
            Assert.AreEqual("драма", videoInfo.Genres);
            Assert.AreEqual("День труда", videoInfo.Name);
            Assert.AreEqual(new TimeSpan(1, 51, 13), videoInfo.Duration);
            Assert.AreEqual(2013, videoInfo.Year);

            Assert.IsNotNull(videoInfo.Cover);
            Assert.AreEqual(@"Одинокая мать укрывает беглого убийцу в своем доме, где живет вместе с сыном. Полиция обшаривает весь городок в поисках преступника, а мать-одиночка, тем временем, узнает о своем «госте» горькую правду и перестает понимать, что же ей делать.CtrlHD!", videoInfo.Description);
        }

        [Test()]
        public async Task ParseVideoInfo_Yazik()
        {
            var updater = new RutrackerInfoParser();

            

            string page = GetPage(@"Resources\yazik.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual(@"Ширли МакЛейн, Дебра Уингер, Джек Николсон, Дэнни ДеВито, Джефф Дэниелс, Джон Литгоу, Лиза Харт Кэрролл, Бетти Кинг, Huckleberry Fox, Трой Бишоп", videoInfo.Artist);
            Assert.AreEqual("Джеймс Л. Брукс / James L. Brooks", videoInfo.Director);
            Assert.AreEqual("драма, мелодрама, комедия", videoInfo.Genres);
            Assert.AreEqual("Язык нежности", videoInfo.Name);
            Assert.AreEqual(new TimeSpan(2, 11, 51), videoInfo.Duration);
            Assert.AreEqual(1983, videoInfo.Year);

            Assert.IsNotNull(videoInfo.Cover);
            Assert.AreEqual(@"Любая мать гораздо лучше, чем дочь, знает, что той нужно для счастья. Аврора Гринуэй очень любит свою дочь Эмму, но не всегда это показывает. После того, как Аврора овдовела, ей пришлось воспитывать ребенка самой. Прошли годы, девочка выросла, вышла замуж и выпорхнула из родового гнезда.", videoInfo.Description);
        }

        [Test()]
        public async Task ParseVideoInfo_Malenkie()
        {
            var updater = new RutrackerInfoParser();



            string page = GetPage(@"Resources\malenkie.html");

            var videoInfo = await updater.ParseVideoInfo(page);

            Assert.AreEqual("Сирша Ронан, Эмма Уотсон, Флоренс Пью, Мэрил Стрип, Элайза Сканлен, Лора Дерн, Тимоти Шаламе, Трэйси Леттс, Боб Оденкёрк, Джеймс Нортон, Луи Гаррель", videoInfo.Artist);
            Assert.AreEqual("Грета Гервиг / Greta Gerwig", videoInfo.Director);
            Assert.AreEqual("Драма, мелодрама", videoInfo.Genres);
            Assert.AreEqual("Маленькие женщины", videoInfo.Name);
            Assert.AreEqual(2019, videoInfo.Year);

            Assert.AreEqual(@"Фильм рассказывает о взрослении четырех непохожих друг на друга сестер. Действие разворачивается во времена Гражданской войны в США, но проблемы, с которыми сталкиваются девушки, актуальны как никогда: первая любовь, горькое разочарование, томительная разлука и непростые поиски себя и своего места в жизни.", videoInfo.Description);
            Assert.IsNotNull(videoInfo.Cover);
            Assert.AreEqual("https://www.kinopoisk.ru/film/807339", videoInfo.KinopoiskLink);
            Assert.AreEqual(new TimeSpan(2, 14, 54), videoInfo.Duration);
        }

        [Test()]
        public async Task ParseVideoInfo_Godunov()
        {
            var updater = new RutrackerInfoParser();

            string page = GetPage(@"Resources\Godunov1.html");

            var info = await updater.ParseAudioInfo(page);

            Assert.AreEqual("Пушкин Александр Сергеевич - Борис Годунов [Д. Назаров, Ю. Васильев, Б. Плотников, А. Феклистов и др., 2009 г., 256 kbps, MP3]", info.Name);
            Assert.AreEqual("Борис Годунов", info.BookTitle);
            Assert.AreEqual("Александр Сергеевич Пушкин", info.Author);
            Assert.AreEqual("Д. Назаров, Ю. Васильев, Б. Плотников, А. Феклистов и др.", info.Voice);
        }

        [Test()]
        public async Task ParseVideoInfo_GoraVols()
        {
            var updater = new RutrackerInfoParser();

            string page = GetPage(@"Resources\Gora1.html");

            var info = await updater.ParseAudioInfo(page);

            Assert.AreEqual("Манн Томас - Волшебная гора [Терновский Евгений, 2013 г., 96 kbps, MP3]", info.Name);
            Assert.AreEqual("Волшебная гора", info.BookTitle);
            Assert.AreEqual("Томас Манн", info.Author);
            Assert.AreEqual("Терновский Евгений", info.Voice);
        }

        private static string GetPage(string path)
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
            Encoding encoding = Encoding.GetEncoding("windows-1251");
            var page = File.ReadAllText(path, encoding);
            return page;
        }


        //        Assert.AreEqual("Жить / Huo zhe / Lifetimes / Living / To Live", videoInfo.Artist);
        //            Assert.IsNotNull(videoInfo.Cover);
        //            Assert.AreEqual(@"Действие этой семейной саги происходит в Китае в течении трех десятилетий - в 1940-60 гг. Наследник уважаемой в городе семьи, Фу Гуй - заядлый игрок. Злоключания его семьи начинаются с того, что однажды он проигрывает свой дом....

        //Одна из лучших, на мой взгляд, работ Чжана Имоу. С одной стороны - масштабнейшее историческое полотно, может быть, самых страшных лет китайской истории, с другой - тончайший рассказ об обычной семье. И вроде как самые страшные годы, но при этом в фильме нет ни одного плохого человека.

        //Очень грустный и при этом невероятно жизнеутверждающий фильм. После него действительно хочется жить. Мудрый Имоу, сам в те годы прошедший и через ссылку, и через исправительные работы, очень убедительно доказывает - жить на свете стоит, даже если тебя угораздило родиться в интересное время в нескучной стране.", videoInfo.Description);
        //            Assert.AreEqual("Чжан Имоу / Yimou Zhang", videoInfo.Director);
        //            Assert.AreEqual(new TimeSpan(2, 12, 35), videoInfo.Duration);
        //            //Assert.AreEqual("Жить / Huo zhe / Lifetimes / Living / To Live", videoInfo.Genres);
        //            Assert.AreEqual(3815028, videoInfo.Id);
        //            //Assert.AreEqual("Жить / Huo zhe / Lifetimes / Living / To Live", videoInfo.KinopoiskLink);
        //            Assert.AreEqual("Жить / Huo zhe / Lifetimes / Living / To Live", videoInfo.Name);
        //            Assert.AreEqual("Жить / Huo zhe / Lifetimes / Living / To Live", videoInfo.Url);
        //            Assert.AreEqual(1994, videoInfo.Year);

        //        }
    }
}