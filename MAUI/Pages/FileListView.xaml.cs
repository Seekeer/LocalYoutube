using MAUI.ViewModels;

namespace MAUI.Pages;

public partial class FileListView : ContentView
{
	public FileListView()
	{
		InitializeComponent();
	}

    private void ListView_ItemTapped(object sender, ItemTappedEventArgs e)
    {
        (BindingContext as ListVM).ItemTapped(e.Item as VideoFileResultDtoDownloaded);
    }
    private void Button_Clicked(object sender, EventArgs e)
    {
        var button = (Button)sender;
        var stack = (Layout)button.Parent;
        stack.Remove(button);
    }
}