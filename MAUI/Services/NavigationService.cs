using MAUI.Pages;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MAUI.Services
{
    public interface INavigationService
    {
        Task GoBack();
        Task NavigateAsync(string route, IDictionary<string, object> parameters = null);
        Task NavigateAsync(string route, object dto);
        Task NavigateToPlayer(object dto);
    }

    internal class NavigationService : INavigationService
    {
        public Task NavigateAsync(string route, IDictionary<string, object> parameters = null)
            => parameters is not null
            ? Shell.Current.GoToAsync(route, parameters)
            : Shell.Current.GoToAsync(route);

        public Task GoBack() => Shell.Current.GoToAsync("..");

        public Task NavigateAsync(string route, object dto)
        {
            var dic = new Dictionary<string, object>
            {
                { "dto", dto }
            };

            return this.NavigateAsync(route, dic);
        }

        /// <summary>
        /// TODO - MAUI bug
        /// </summary>
        /// <param name="dto"></param>
        /// <returns></returns>
        public async Task NavigateToPlayer(object dto)
        {
            //var playerPage = Shell.Current.CurrentPage as Player;
            //if (playerPage != null)
            //    playerPage.GetMedia().Pause();
            //await Shell.Current.Navigation.PushAsync(nameof(Player), dto);
            await Shell.Current.Navigation.PopAsync();
        }
    }
}
