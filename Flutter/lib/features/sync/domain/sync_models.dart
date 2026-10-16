/// Where the app's single SignalR connection stands.
///
/// It says nothing about who else is online: a device is reached through the Cast Session
/// protocol, by the stable identity it registered under, and never by a connection.
enum SyncConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}
