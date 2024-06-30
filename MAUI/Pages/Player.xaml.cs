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
        BindingContext = vm;
        vm.Page = this;
    }

    private void Player_NavigatedFrom(object? sender, NavigatedFromEventArgs e)
    {
        MediaElement.Dispose();
        MediaElement.Stop();
    }

    internal TimeSpan GetCurrentPosition()
    {
        return _lastPosition.LastOrDefault();
    }

    internal async Task SetPosition(TimeSpan time)
    {
        var toast = Toast.Make($"Navigate to {time.TotalSeconds}", ToastDuration.Short, 14);
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
        this.SetPosition(TimeSpan.FromMinutes(1.5));
        //viewModel.UpdatePositionByControl();
    }
}