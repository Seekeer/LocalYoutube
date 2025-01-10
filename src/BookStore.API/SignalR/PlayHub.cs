using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.SignalR;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace API.SignalR
{
    [Authorize]
    public class PlayHub : Hub
    {
        private string? ADMIN_USER_NAME = "tt";

        private static readonly Dictionary<string, Dictionary<string, string>> _usersConnectionsDictionary = new();

        public async Task Play(string connectionId, int videoId, TimeSpan position)
        {
            await this.Clients.Client(connectionId).SendAsync("PlayOnClient", videoId, position);
        }

        public override async Task OnDisconnectedAsync(Exception exception)
        {
            var userName = GetUserName();

            if(_usersConnectionsDictionary.ContainsKey(userName))
                if(_usersConnectionsDictionary[userName].ContainsKey(Context.ConnectionId))
                    _usersConnectionsDictionary[userName].Remove(Context.ConnectionId);

            KeyValuePair<string, string> record = CreateRecord();
            await NotifyAllUsersAboutConnection(userName, record, false);

            NLog.LogManager.GetCurrentClassLogger().Info($"User diconnected: {record.Key}:{record.Key}");
            await base.OnDisconnectedAsync(exception);
            return ;
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserName();
            if (!_usersConnectionsDictionary.ContainsKey(userId))
                _usersConnectionsDictionary[userId] = new Dictionary<string, string>();

            KeyValuePair<string, string> record = CreateRecord();

            await NotifyAllUsersAboutConnection(userId, record, true);

            _usersConnectionsDictionary[userId].Add(record.Key, record.Value);

            NLog.LogManager.GetCurrentClassLogger().Info($"User connected: {record.Key}:{record.Value}");
            await base.OnConnectedAsync();          

            return;
        }

        private KeyValuePair<string, string> CreateRecord()
        {
            var httpFeature = Context.Features.Get<IHttpConnectionFeature>();

            var record = new KeyValuePair<string, string>(Context.ConnectionId, $"{GetUserName()}_{httpFeature.RemoteIpAddress}:{httpFeature.RemotePort}");
            return record;
        }

        private async Task NotifyAllUsersAboutConnection(string userName, KeyValuePair<string, string> record, bool isConnected)
        {
            // Notify admins about connected user
            if (!IsAdmin())
            {
                if (_usersConnectionsDictionary.ContainsKey(ADMIN_USER_NAME))
                    foreach (var item in _usersConnectionsDictionary[ADMIN_USER_NAME]) 
                        await NotifyAboutConnectionChanged(item.Key, record, isConnected);
            }
            else
            {
                if (isConnected)
                {
                    foreach (var item in _usersConnectionsDictionary.SelectMany(x => x.Value))
                        await NotifyAboutConnectionChanged(record.Key, item, isConnected);
                }
            }

            foreach (var item in _usersConnectionsDictionary[userName])
                await NotifyAboutConnectionChanged(item.Key, record, isConnected);
        }

        private string GetUserName()
        {
            return Context.User.Identity.Name;
        }

        private bool IsAdmin()
        {
            return GetUserName().Equals(ADMIN_USER_NAME);
        }

        private async Task NotifyAboutConnectionChanged(string connectionId, KeyValuePair<string, string> item, bool isConnected)
        {
            await this.Clients.Clients(connectionId).SendAsync(isConnected ? "Connected" : "Disconnected", item.Key, item.Value);
        }
    }
}

