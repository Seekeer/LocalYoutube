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
}