using FileStore.Domain.Dtos;
using MAUI.Pages;
using System.Text.Json;

namespace MAUI.Services
{
    public class HttpClientAuth
    {
        public HttpClientAuth(INavigationService navigationService) 
        {
            _navigationService = navigationService;
        }

        public static async Task<bool> LoginAsync(string login, string pass)
        {
            var json = JsonSerializer.Serialize(new LoginRequest { UserName = login, Password = pass });
            return await SendLoginData( json, "login");
        }

        private static async Task<bool> SendLoginData(string json, string url)
        {
            using var client = new HttpClient();
            StringContent httpContent = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            try
            {
                var response = await client.PostAsync($"{BASE_API_URL}account/{url}", httpContent);

                LoginResult result = await Parse<LoginResult>(response);

                await SaveLoginResult(result);

                return true;
            }
            catch (Exception ex)
            {
                return false;
            }
        }

        private async Task<bool> RefreshToken()
        {
            var json = JsonSerializer.Serialize(new RefreshTokenRequest
            {
                UserName = await SecureStorage.GetAsync("user_name"),
                RefreshToken = await SecureStorage.GetAsync("refresh_token"),
            });

            return await SendLoginData(json, "refresh-token");
        }

        private static async Task SaveLoginResult(LoginResult result)
        {
            await SecureStorage.SetAsync("user_name", result.UserName);
            await SecureStorage.SetAsync("accessToken", result.AccessToken);
            await SecureStorage.SetAsync("refresh_token", result.RefreshToken);
        }

        public static void ClearTokens()
        {
            SecureStorage.Remove("user_name");
            SecureStorage.Remove("accessToken");
            SecureStorage.Remove("refresh_token");
        }

        //public const string BASE_API_URL = @"http://192.168.1.55:51951/api/";
        public const string BASE_API_URL = @"http://80.68.9.86:55/api/";

        private readonly INavigationService _navigationService;

        internal static string GetVideoUrlById(int id)
        {
            return $"{HttpClientAuth.BASE_API_URL}Files/getFileById?fileId={id}";
        }

        public async Task<T> Put<T>(string url, object data)
        {
            using var client = await GetClient();

            var json = JsonSerializer.Serialize(data);
            StringContent httpContent = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            url = !url.StartsWith(BASE_API_URL) ? $"{BASE_API_URL}{url}" : url;
            var response = await client.PutAsync(url, httpContent);

            if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized)
            {
                if (!await RefreshToken())
                {
                    ClearTokens();
                    await _navigationService.NavigateAsync(nameof(LoginPage));
                }
                else
                    return await Put<T>(url, data);
            }

            if (typeof(T) == typeof(string))
                return await response.Content.ReadAsAsync<T>();

            T? obj = await Parse<T>(response);

            return obj;
        }

        public async Task<T> GetAsync<T>(string url)
        {
            using var client = await GetClient();
            url = ! url.StartsWith(BASE_API_URL) ? $"{BASE_API_URL}{url}" : url;
            var response = await client.GetAsync(url);

            if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized)
            {
                if (!await RefreshToken())
                {
                    ClearTokens();
                    await _navigationService.NavigateAsync(nameof(LoginPage));
                }
                else
                    return await GetAsync<T>(url);
                ////await SecureStorage.SetAsync("accessToken", result.AccessToken);
                //if (Preferences.Default.ContainsKey(AuthConsts.RefreshTokenKeyName))
                //{
                //    var refreshTokenValue = Preferences.Default.Get(AuthConsts.RefreshTokenKeyName, "");
                //    var refreshResult = await OidcClient.RefreshTokenAsync(refreshTokenValue?.ToString());

                //    Preferences.Default.Set(AuthConsts.AccessTokenKeyName, refreshResult.AccessToken);
                //    Preferences.Default.Set(AuthConsts.RefreshTokenKeyName, refreshResult.RefreshToken);

                //    request.SetBearerToken(refreshResult.AccessToken);

                //    return await base.SendAsync(request, cancellationToken);
                //}
                //else
                //{
                //    var result = await OidcClient.LoginAsync(new LoginRequest());
                //    request.SetBearerToken(result.AccessToken);

                //    Preferences.Default.Set(AuthConsts.AccessTokenKeyName, result.AccessToken);
                //    Preferences.Default.Set(AuthConsts.RefreshTokenKeyName, result.RefreshToken);
                //    request.SetBearerToken(result.AccessToken);

                //    return await base.SendAsync(request, cancellationToken);
                //}
            }

            T? list = await Parse<T>(response);

            return list;
        }

        private static async Task<T?> Parse<T>(HttpResponseMessage response)
        {
            var respStr = await response.Content.ReadAsStringAsync();
            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            };
            var list = JsonSerializer.Deserialize<T>(respStr, options);

            return list;
        }

        private async Task<HttpClient> GetClient()
        {
            var token = await SecureStorage.GetAsync("accessToken");
            var http = new HttpClient();
            http.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

            return http;
        }

        internal static async Task<bool> IsAuthenticated()
        {
            //TODO no network
            //return true;
            var token = await SecureStorage.GetAsync("accessToken");
            return !string.IsNullOrEmpty(token);
        }

    }
}
