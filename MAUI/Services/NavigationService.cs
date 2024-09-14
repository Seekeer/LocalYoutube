using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static MAUI.Services.DeviceOrientationService;

namespace MAUI.Services
{
    public interface INavigationService
    {
        Task GoBack();
        Task NavigateAsync(string route, IDictionary<string, object> parameters = null);
        Task NavigateAsync(string route, object dto);
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
    }
    public partial class DeviceOrientationService : IDeviceOrientationService
    {
        public partial void SetDeviceOrientation(DisplayOrientation displayOrientation);
    }

    public interface IDeviceOrientationService
    {
        void SetDeviceOrientation(DisplayOrientation displayOrientation);
    }
}
