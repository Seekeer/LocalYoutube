using CommunityToolkit.Maui.Views;
using Dtos;
using MAUI.ViewModels;

namespace MAUI.Pages;

public partial class Player : ContentPage
{
    private List<TimeSpan> _lastPosition = new List<TimeSpan>();

    public Player(PlayerVM vm)
	{
		InitializeComponent();

        BindingContext = vm;
        vm.Page = this;
    }

    public MediaElement PlayerElement { get { return MediaElement; } }

    private PlayerVM viewModel => BindingContext as PlayerVM;

    protected override bool OnBackButtonPressed()
    {
        MediaElement.Dispose();
        MediaElement.Stop();
        return base.OnBackButtonPressed();
    }

    private void OnPositionChanged(object sender, 
        CommunityToolkit.Maui.Core.Primitives.MediaPositionChangedEventArgs e)
    {
        _lastPosition.Add(e.Position);
    }

    private void MediaElement_SeekCompleted(object sender, EventArgs e)
    {
        viewModel.SeekPositionCollection.TryAddPosition(_lastPosition, MediaElement.Position);
    }
}