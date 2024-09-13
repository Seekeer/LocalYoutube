using MAUI.ViewModels;

namespace MAUI.Pages;

public partial class FreshPage : ContentPage
{
	public FreshPage(FreshVM vm)
    {
        InitializeComponent();
        BindingContext = vm;
    }

    private ListVM viewModel => BindingContext as ListVM;
}