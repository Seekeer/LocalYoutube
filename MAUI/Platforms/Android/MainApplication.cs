using Android.App;
using Android.Bluetooth;
using Android.Content;
using Android.Media;
using Android.Media.Session;
using Android.Runtime;
using Android.Telephony;
using Android.Views;
using MAUI.Platforms.Android;
using static Microsoft.Maui.ApplicationModel.Platform;

namespace MAUI
{
    [Application(UsesCleartextTraffic = true)]
    public class MainApplication : MauiApplication
    {
        public MainApplication(IntPtr handle, JniHandleOwnership ownership)
            : base(handle, ownership)
        {
            var telephonyManager = (TelephonyManager)GetSystemService(TelephonyService);
            var phoneCallListener = new PhoneCallListener();
            telephonyManager.Listen(phoneCallListener, PhoneStateListenerFlags.CallState);

            //var bluetoothManager = (BluetoothManager)GetSystemService(BluetoothService);
            //var devices = bluetoothManager.GetConnectedDevices(ProfileType.Headset);

            //foreach (var device in devices)
            //{
            //    //if(device is BluetoothHeadset headset)
            //}

            //var service = (MediaSession)GetSystemService(MediaSessionService);
            //service.SetCallback(new MediaSession.Callback())

            var audioManager = (AudioManager)GetSystemService(AudioService);
            audioManager.RegisterAudioPlaybackCallback(new AudioListener(), new Android.OS.Handler() { });
            audioManager.RegisterAudioDeviceCallback(new AudioDevice(), new Android.OS.Handler() { });

            var filter = new IntentFilter(Android.Content.Intent.ActionMediaButton);
            filter.Priority = 1000;
            var a = RegisterReceiver(new CustomReciever(),filter );
            //a = RegisterReceiver(new CustomReciever(), new IntentFilter("com.companyname.devtube"+ Android.Content.Intent.ActionMediaButton));
            //a = RegisterReceiver(new CustomReciever(), new IntentFilter("com.companyname.devtube" + Android.Content.Intent.ActionAirplaneModeChanged));
            a = RegisterReceiver(new CustomReciever(), new IntentFilter(Android.Content.Intent.ActionAirplaneModeChanged));
            a = RegisterReceiver(new CustomReciever(), new IntentFilter(Android.Content.Intent.ExtraKeyEvent));
            //service.SetCallback(new MediaSession.Callback())
        }

        public static MauiApp MAUI_APP { get; private set; }

        protected override MauiApp CreateMauiApp()
        {
            MAUI_APP = MauiProgram.CreateMauiApp();

            return MAUI_APP;

        }
    }
}
