using Infrastructure;
using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Core.Tests.MAUI
{
    internal class VideoDescriptionRowVMTests
    {
        [Test()]
        public async Task ParseDescription()
        {
            var descriptionRowVMs = VideoDescriptionRowVM.ParseDescription(@"
                Обучение финансам и управлению в Академии Eduson — https://www.eduson.tv/~asafev_finance
По промокоду АСАФЬЕВ скидка 65 %, а также курс по работе с нейросетями в подарок!
_
Товары для спорта с выгодой на Мегамаркете: https://bit.ly/megamarket_asafiev_life__
Активируйте промокод ВСЕМСПОРТ и получите скидку 2 000 рублей при первом заказе от 7 000 рублей.Правила промокода: https://bit.ly/megamarket_asafiev_life___
            _
            Кутёж и великолепный мерч
            https://market.yandex.ru/store--kutezh?businessId=84407784
_
Наш Boosty — https://boosty.to/asafevstas
            Наше сообщество в ВК — https://vk.com/asafevstas 
            И канал в Телеграме — https://t.me/asafevstas   
            _
            Чтобы попасть в нашу команду, смотрите вакансии тут — https://asafev.ru 
            А чтобы показать ваш авто в обзоре, заполните данные тут — https://forms.yandex.ru/u/6630b5d2f47e734a79d9e6fd/ 
            _
            Таймкоды: 
00:00 Ссылка в описании
00:10 Приветики
01:13 У нас гости!
06:42 Нюансы регионов
10:29 Все о правом руле
14:22 Божественная интеграция
15:39 Детская автомобильная мечта
24:17 Контрабанда Крузаков
25:40 Бронированная Toyota для Бразилии
29:09 Haval для Михеева
31:35 Рост спроса на каучук
34:08 Поляна из Tesla
36:03 BMW M5 для семьянинов
38:44 Rimac отпугивает покупателей
41:06 Спорная опция BMW
44:29 Самые угоняемые китайцы
47:17 Кибертрак Кадырова
49:26 Jaguar останется без машин
52:21 Red Bull продает WRC
1:01:05 Рост зарплат дальнобойщиков
1:04:25 Ford откажется от электрички
1:06:24 Инвесторы судятся со Stellantis
1:10:24 Citroen уходит из Австралии
1:12:57 Пошлины на китайские Tesla
1:14:24 Chery в стиле Range Rover
1:16:29 Послевкусие
_
Подбор автомобилей с пробегом в легендарном Автопрагмате — https://clck.ru/395JJt
            _
            Контраварийное вождение и дрифт в не менее легендарной школе Ратата — https://ratata.ru/
            _
            Обслуживание авто VAG группы в сервисе Zimwerk — https://clck.ru/394xoB
            _
            Размещение рекламы — reklama @asafev.ru
            _
00.00 Реклама.Рекламодатель ООО «МАРКЕТПЛЕЙС», ИНН 9701048328 erid: 2VtzqurP565
14.53 Реклама.ООО «Эдюсон», ИНН 7729779476.erid: LjN8JziJg"
                , true);

            Assert.IsTrue(descriptionRowVMs.Count() > 1);
            Assert.IsTrue(descriptionRowVMs.Any(x => !string.IsNullOrEmpty(x.Timestamp)));
        }
    }
}
