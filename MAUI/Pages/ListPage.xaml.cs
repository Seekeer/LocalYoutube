using Dtos;
using MAUI.ViewModels;

namespace MAUI.Pages;

public partial class ListPage : ContentPage
{
	public ListPage(ListVM vm)
	{
		InitializeComponent();
        BindingContext = vm;
    }

    private ListVM viewModel => BindingContext as ListVM;

    private void ListView_ItemTapped(object sender, ItemTappedEventArgs e)
    {
        viewModel.ItemTapped(e.Item as VideoFileResultDtoDownloaded);
    }

    private void Button_Clicked(object sender, EventArgs e)
    {
        var button = (Button)sender;
        var stack = (StackLayout)button.Parent;
        stack.Remove(button);
    }
}