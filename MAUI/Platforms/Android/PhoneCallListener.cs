using Android.Content;
using Android.Media;
using Android.Telephony;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static Android.Media.AudioManager;

namespace MAUI.Platforms.Android
{
    public class PhoneCallListener : PhoneStateListener
    {
        public override void OnCallStateChanged(CallState state, string incomingNumber)
        {
            base.OnCallStateChanged(state, incomingNumber);


            if (state == CallState.Ringing)
            {
                // Retrieve the caller ID information string callerId = TelephonyManager.FromContext(Application.Context).GetLine1Number(); 
                // Do something with the caller ID information Console.WriteLine($"Incoming call from {callerId}"); } } } 
                (App.Current as App)?.PausePlay();
            }
            else if (state == CallState.Offhook)
            {
            }
            else if (state == CallState.Idle)
            {
                (App.Current as App)?.ResumePlay();
            }
        }
    }
    public class AudioListener : AudioPlaybackCallback
    {
        public override void OnPlaybackConfigChanged(IList<AudioPlaybackConfiguration>? configs)
        {
            base.OnPlaybackConfigChanged(configs);
        }
    }

    public class AudioDevice : AudioDeviceCallback
    {
        public override void OnAudioDevicesRemoved(AudioDeviceInfo[]? removedDevices)
        {
            base.OnAudioDevicesRemoved(removedDevices);
        }
    }

    public class CustomReciever : BroadcastReceiver
    {
        public override void OnReceive(Context? context, Intent? intent)
        {
            Console.WriteLine("CustomReciever");
            //if (Android.Content.Intent.ACTION_MEDIA_BUTTON.equals(intent.getAction()))
            //{
            //    KeyEvent event = (KeyEvent) intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);
            //if (KeyEvent.KEYCODE_MEDIA_PLAY == event.getKeyCode()) {
            //    // Handle key press.
            //}
        }
    }
}
