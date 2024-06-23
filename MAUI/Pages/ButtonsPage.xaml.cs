using MAUI.ViewModels;

namespace MAUI.Pages;

public partial class ButtonsPage : ContentPage
{
	public ButtonsPage(ButtonsVM vm)
	{
		InitializeComponent();
        BindingContext = vm;
    }

    private ButtonsVM viewModel => BindingContext as ButtonsVM;

}