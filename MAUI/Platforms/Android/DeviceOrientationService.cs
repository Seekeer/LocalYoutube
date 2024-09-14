using Android.Content.PM;
using MAUI.Services;

namespace MAUI.Platforms.Android
{
    public partial class DeviceOrientationService 
    {

        private static readonly IReadOnlyDictionary<DisplayOrientation, ScreenOrientation> _androidDisplayOrientationMap =
            new Dictionary<DisplayOrientation, ScreenOrientation>
            {
                [DisplayOrientation.Landscape] = ScreenOrientation.Landscape,
                [DisplayOrientation.Portrait] = ScreenOrientation.Portrait,
            };

        public partial async Task SetDeviceOrientation(DisplayOrientation displayOrientation)
        {
            var currentActivity = ActivityStateManager.Default.GetCurrentActivity();
            if (currentActivity is not null)
            {
                if (_androidDisplayOrientationMap.TryGetValue(displayOrientation, out ScreenOrientation screenOrientation))
                {
                    currentActivity.RequestedOrientation = screenOrientation;
                }
            }

            await Task.Delay(100);
        }
    }
}
