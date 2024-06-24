using Dtos;
using FileStore.Domain.Dtos;
using MAUI.Pages;
using Sentry.Protocol;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Windows.Media.Protection.PlayReady;
using static System.Net.WebRequestMethods;

namespace MAUI.Services
{
    public interface IAPIService
    {
        Task<IEnumerable<VideoFileResultDto>> GetHistoryAsync();
    }

    public class APIService : IAPIService
    {
        private readonly HttpClientAuth _httpClientAuth;

        public APIService(HttpClientAuth httpClientAuth) {
            _httpClientAuth = httpClientAuth;
        }

        //clearLocalStorage()
        //{
        //    localStorage.removeItem('user_name');
        //    localStorage.removeItem('access_token');
        //    localStorage.removeItem('refresh_token');
        //    localStorage.setItem('logout-event', 'logout' + Math.random());
        //}

        //        login(username: string, password: string)
        //        {
        //            return this.http
        //              .post<LoginResult>(`${ this.apiUrl}/ login`, { username, password })
        //      .pipe(
        //        map((x) => {
        //        this._user.next({
        //        username: x.username,
        //            role: x.role,
        //            originalUserName: x.originalUserName,
        //          });
        //            this.setLocalStorage(x);
        //            this.startTokenTimer();
        //            return x;
        //        })
        //      );

        //  refreshToken() : Observable<LoginResult | null> {
        //    const refreshToken = localStorage.getItem('refresh_token');
        //        const userName = localStorage.getItem('user_name');
        //    if (!refreshToken) {
        //      this.clearLocalStorage();
        //      return of(null);
        //    }

        //    return this.http
        //      .post<LoginResult>(`${this.apiUrl}/refresh-token`, { refreshToken, userName
        //})
        //      .pipe(
        //        map((x) => {
        //        this._user.next({
        //        username: x.username,
        //            role: x.role,
        //            originalUserName: x.originalUserName,
        //          });
        //this.setLocalStorage(x);
        //this.startTokenTimer();
        //return x;
        //        })
        //      );
        //  }
        //}

        public async Task<IEnumerable<VideoFileResultDto>> GetHistoryAsync()
        {
            var list = await _httpClientAuth.GetAsync<IEnumerable<VideoFileResultDto>>($"files/getLatest");
            return list;

            //TODO no network
            var list1 = new List<VideoFileResultDto>
            {
                new VideoFileResultDto
                {
                    CoverURL = "https://60.img.avito.st/image/1/1.e2WiAra414yUqxWJ2Gc0S8ag1Yoco1WE1KbVjhKr34YU.X0s5Dlazk8TBFZ-ZiyhhavQCV88ptt5n4-nzxyrEPOM",
                    Name = "Мое видео",
                    Description = "Описание",
                    Id = 55664
                }
            };
            return list1;
        }

    }

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
            var client = new HttpClient();
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

            return await SendLoginData(json, "login");
        }

        private static async Task SaveLoginResult(LoginResult result)
        {
            await SecureStorage.SetAsync("user_name", result.UserName);
            await SecureStorage.SetAsync("accessToken", result.AccessToken);
            await SecureStorage.SetAsync("refresh_token", result.RefreshToken);
        }

        private static void ClearTokens()
        {
            SecureStorage.Remove("user_name");
            SecureStorage.Remove("accessToken");
            SecureStorage.Remove("refresh_token");
        }

        public const string BASE_API_URL = @"http://80.68.9.86:55/api/";
        private readonly INavigationService _navigationService;

        internal static string GetVideoUrlById(int id)
        {
            return $"{HttpClientAuth.BASE_API_URL}Files/getFileById?fileId={id}";
        }

        public async Task<T> GetAsync<T>(string url)
        {
            var client = await GetClient();
            url = $"{BASE_API_URL}{url}";
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
            return true;
            var token = await SecureStorage.GetAsync("accessToken");
            return !string.IsNullOrEmpty(token);
        }

    }
}
