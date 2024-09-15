using MAUI.ViewModels;

namespace MAUI.Pages;

public partial class FileListView : ContentView
{
	public FileListView()
	{
		InitializeComponent();
	}

    private void Button_Clicked(object sender, EventArgs e)
    {
        var button = (Button)sender;
        var stack = (Layout)button.Parent;
        stack.Remove(button);
    }

    private void SwipeItem_Clicked(object sender, EventArgs e)
    {
        //var button = (SwipeItem)sender;
        //var stack = (SwipeView)button.Parent;
        //stack.Remove(button);
    }

    private void OnUrlClicked(object sender, TappedEventArgs e)
    {
        var dto = (VideoFileResultDtoDownloaded)e.Parameter;
        (BindingContext as ListVM).ItemTapped(dto);
    }
}