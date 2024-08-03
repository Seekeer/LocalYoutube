using MAUI.ViewModels;

namespace MAUI.Pages;

public partial class SeriesPage : ContentPage
{
	public SeriesPage(SeriesVM vm)
    {
        InitializeComponent();
        BindingContext = vm;
    }

    private ListVM viewModel => BindingContext as ListVM;
}