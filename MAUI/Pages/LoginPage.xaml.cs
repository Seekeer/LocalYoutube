using MAUI.ViewModels;

namespace MAUI.Pages;

public partial class LoginPage : ContentPage
{
    private LoginVM viewModel => BindingContext as LoginVM;

    public LoginPage(LoginVM vm)
	{
		InitializeComponent();
        BindingContext = vm;
    }

    protected override async void OnNavigatedTo(NavigatedToEventArgs args)
    {
        await viewModel.OnNavigated();

        base.OnNavigatedTo(args);
    }

    protected override bool OnBackButtonPressed()
    {
        Application.Current.Quit();
        return true;
    }
}