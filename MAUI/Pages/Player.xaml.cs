using CommunityToolkit.Maui.Alerts;
using CommunityToolkit.Maui.Core;
using CommunityToolkit.Maui.Views;
using Dtos;
using MAUI.ViewModels;
using System.Threading;

namespace MAUI.Pages;

public partial class Player : ContentPage
{

    public Player(PlayerVM vm)
	{
		InitializeComponent();

        this.NavigatedFrom += Player_NavigatedFrom;
        BindingContext = vm;
        vm.Page = this;
    }

    public MediaElement GetMedia()
    {
        return MediaElement;
    }

    private void Player_NavigatedFrom(object? sender, NavigatedFromEventArgs e)
    {
        MediaElement.Stop();
        MediaElement.Dispose();
        Toast.Make($"Player_NavigatedFrom", ToastDuration.Long, 20).Show();
    }

    internal async Task SetPosition(TimeSpan time)
    {
        if (time == TimeSpan.Zero)
            return;

        var toast = Toast.Make($"Navigated to {viewModel.VideoUrl}", ToastDuration.Short, 14);
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

    private void OnPositionChanged(object sender, CommunityToolkit.Maui.Core.Primitives.MediaPositionChangedEventArgs e)
    {
        //var toast = Toast.Make($"OnPositionChanged {e.Position}", ToastDuration.Short, 14);
        //_lastPosition.Add(e.Position);
    }

    private void MediaElement_SeekCompleted(object sender, EventArgs e)
    {
        //var toast = Toast.Make($"MediaElement_SeekCompleted {MediaElement.Position}", ToastDuration.Short, 14);
        //if(viewModel.SeekPositionCollection.TryAddPosition(_lastPosition, MediaElement.Position))
        //{
        //    var snackbarOptions = new SnackbarOptions
        //    {
        //        //BackgroundColor = Colors.Red,
        //        //TextColor = Colors.Green,
        //        ActionButtonTextColor = Colors.Purple,
        //        CornerRadius = new CornerRadius(10),
        //        //Font = Font.SystemFontOfSize(14),
        //        //ActionButtonFont = Font.SystemFontOfSize(14),
        //        //CharacterSpacing = 0.5
        //    };

        //    string text = $"Вы переместились на {MediaElement.Position}";
        //    string actionButtonText = "Вернуться обратно";
        //    Action action = async () => await SetPosition(viewModel.SeekPositionCollection.Positions.First().OriginalPosition);
        //    TimeSpan duration = TimeSpan.FromSeconds(8);

        //    Snackbar.Make(text, action, actionButtonText, duration, snackbarOptions).Show();
        //}
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
        var tsString = (sender as Label).BindingContext.ToString();
        if (tsString.Length == 5)
            tsString = $"00:{tsString}";
        var ts = TimeSpan.Parse(tsString);

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

    private void OnTimeClicked(object sender, TappedEventArgs e)
    {
        var label = sender as Label;
        var descriptionRow = (DescriptionRow)label.BindingContext;

        SetPosition(descriptionRow.GetPosition());
    }
}