using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using CommunityToolkit.Maui.Views;
using Dtos;
using MAUI.ViewModels;
using System.Threading;

namespace MAUI.Pages;

public partial class Player : ContentPage
{
    private List<TimeSpan> _lastPosition = new List<TimeSpan>();

    public Player(PlayerVM vm)
	{
		InitializeComponent();

        this.NavigatedFrom += Player_NavigatedFrom;
        this.
        BindingContext = vm;
        vm.Page = this;
    }

    private void Player_NavigatedFrom(object? sender, NavigatedFromEventArgs e)
    {
        MediaElement.Stop();
        MediaElement.Dispose();
        Toast.Make($"Player_NavigatedFrom", ToastDuration.Long, 20).Show();
    }

    internal TimeSpan GetCurrentPosition()
    {
        return _lastPosition.LastOrDefault();
    }

    internal async Task SetPosition(TimeSpan time)
    {
        var toast = Toast.Make($"Navigate to {viewModel.VideoUrl}", ToastDuration.Short, 14);
        //var toast = Toast.Make($"Navigate to {time.TotalSeconds}", ToastDuration.Short, 14);
        await toast.Show();

        MainThread.BeginInvokeOnMainThread(async () =>
        {
            try
            {
                await MediaElement.SeekTo(time);
            }
            catch (Exception ex)
            {
            }
        });
    }

    private PlayerVM viewModel => BindingContext as PlayerVM;

    private void OnPositionChanged(object sender, 
        CommunityToolkit.Maui.Core.Primitives.MediaPositionChangedEventArgs e)
    {
        

        _lastPosition.Add(e.Position);
    }

    private void MediaElement_SeekCompleted(object sender, EventArgs e)
    {
        viewModel.SeekPositionCollection.TryAddPosition(_lastPosition, MediaElement.Position);
    }

    private void OnMediaOpened(object sender, EventArgs e)
    {
        viewModel.InitPosition();
    }

    private void OnStateChanged(object sender, CommunityToolkit.Maui.Core.Primitives.MediaStateChangedEventArgs e)
    {

    }

    private void Button_Clicked(object sender, EventArgs e)
    {
        //this.SetPosition(TimeSpan.FromMinutes(1.5));
        //viewModel.UpdatePositionByControl();
    }

    private void OnUrlClicked(object sender, TappedEventArgs e)
    {
        var label = sender as Label;
        var ts = (TimeSpan)label.BindingContext;

        if (ts == TimeSpan.Zero)
            return;

        SetPosition(ts);
    }

    private void MediaElement_MediaFailed(object sender, CommunityToolkit.Maui.Core.Primitives.MediaFailedEventArgs e)
    {
        Toast.Make($"MediaElement_MediaFailed", ToastDuration.Long, 20).Show();
    }

    private void MediaElement_PropertyChanged(object sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        Toast.Make($"MediaElement_PropertyChanged", ToastDuration.Long, 20).Show();
    }

    private void MediaElement_Unloaded(object sender, EventArgs e)
    {
        Toast.Make($"MediaElement_Unloaded", ToastDuration.Long, 20).Show();

    }
    private void Player_NavigatingFrom(object? sender, NavigatingFromEventArgs e)
    {
        Toast.Make($"Player_NavigatingFrom", ToastDuration.Long, 20).Show();
    }

}