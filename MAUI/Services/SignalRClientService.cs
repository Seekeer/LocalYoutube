//using Microsoft.AspNetCore.SignalR.Client;
//using System;
//using System.Collections.Generic;
//using System.Linq;
//using System.Text;
//using System.Threading.Tasks;

//namespace MAUI.Services
//{
//    internal class SignalRClientService
//    {
//        private void InitSignalR()
//        {
//            _hubConnection = new HubConnectionBuilder()
//                .WithUrl($@"{HttpClientAuth.BASE_SERVER_URL}/player", options =>
//                {
//                    options.AccessTokenProvider = () => _api.GetAccessToken();
//                })
//                .Build();
//            // подключемся к хабу
//            _hubConnection.StartAsync();
//            _hubConnection.On<string, string>("Receive", (user, message) =>
//            {
//                Console.Write(message);
//            });
//            _hubConnection.On<string, string>("Connected", (connectionId, userId) =>
//            {
//                Console.Write($"User: {userId} connected as {connectionId}");
//                _clientsDict.Add(new(connectionId, userId));
//                UpdateClients();
//            });
//            _hubConnection.On<string, string>("Disconnected", (connectionId, userId) =>
//            {
//                Console.Write($"User: {userId} connected as {connectionId}");
//                if (_clientsDict.Any(x => x.Key == connectionId))
//                {
//                    var item = _clientsDict.First(x => x.Key == connectionId);
//                    _clientsDict.Remove(item);
//                    UpdateClients();
//                }
//            });
//            _hubConnection.On<int>("PlayOnClient", (videoId) =>
//            {
//                this.AssignDTO(new VideoFileResultDtoDownloaded
//                {
//                    Id = videoId
//                });
//            });
//        }

//        private HubConnection _hubConnection;

//    }
//}
