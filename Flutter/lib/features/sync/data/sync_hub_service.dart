import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../../../app/router/auth_notifier.dart';
import '../../../core/auth/token_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/logging/log_service.dart';
import '../../../core/network/api_route.dart';
import '../../cast/domain/cast_models.dart';
import '../../cast/domain/cast_session_models.dart';
import '../../player/domain/player_volume.dart';
import '../domain/sync_models.dart';

class SyncHubService {
  SyncHubService({
    required AppConfig appConfig,
    required TokenRepository tokenRepository,
    required AuthNotifier authNotifier,
    required LogService logService,
    required ApiRoute apiRoute,
  })  : _appConfig = appConfig,
        _tokenRepository = tokenRepository,
        _authNotifier = authNotifier,
        _logService = logService,
        _apiRoute = apiRoute;

  final AppConfig _appConfig;
  final TokenRepository _tokenRepository;
  final AuthNotifier _authNotifier;
  final LogService _logService;
  final ApiRoute _apiRoute;

  final StreamController<SyncConnectionState> _connectionStateController =
      StreamController<SyncConnectionState>.broadcast();
  final StreamController<CastDevicesSnapshot> _castDevicesController =
      StreamController<CastDevicesSnapshot>.broadcast();
  final StreamController<CastSession> _castSessionController =
      StreamController<CastSession>.broadcast();
  final StreamController<CastPrepareCommand> _castPrepareController =
      StreamController<CastPrepareCommand>.broadcast();
  final StreamController<CastCommitCommand> _castCommitController =
      StreamController<CastCommitCommand>.broadcast();
  final StreamController<CastCommand> _castCommandController =
      StreamController<CastCommand>.broadcast();

  CastDevicesSnapshot _castDevices = CastDevicesSnapshot.empty;

  HubConnection? _hubConnection;
  SyncConnectionState _connectionState = SyncConnectionState.disconnected;
  bool _initialized = false;
  bool _isDisposed = false;
  bool _isConnecting = false;

  SyncConnectionState get connectionState => _connectionState;

  /// The account's cast devices as the API last reported them.
  CastDevicesSnapshot get castDevices => _castDevices;

  /// Every authoritative cast-device snapshot the API reports: the answer to a registration and
  /// every later change on the account, which arrive without registering again.
  Stream<CastDevicesSnapshot> watchCastDevices() =>
      _castDevicesController.stream;

  /// Every change to the Cast Session this device takes part in. Always the whole session, so a
  /// client that missed a message still converges on the next one.
  Stream<CastSession> watchCastSession() => _castSessionController.stream;

  /// Every phase-one Handoff command the API sends this device as a Receiver: load this video and
  /// wait. Nothing that is playing here changes until the commit arrives.
  Stream<CastPrepareCommand> watchCastPrepareCommands() =>
      _castPrepareController.stream;

  /// Every phase-two Handoff command the API sends this device as a Receiver, carrying where the
  /// viewer actually is and whether they were playing or paused.
  Stream<CastCommitCommand> watchCastCommitCommands() =>
      _castCommitController.stream;

  /// Every Controller command the API sends this device as a Receiver, each numbered by its
  /// session so a command that has been overtaken can be recognised as old.
  Stream<CastCommand> watchCastCommands() => _castCommandController.stream;

  Stream<SyncConnectionState> watchConnectionState() =>
      _connectionStateController.stream;

  Future<void> initialize() async {
    if (_initialized || _isDisposed) {
      return;
    }
    _initialized = true;
    _authNotifier.addListener(_onAuthStateChanged);
    _emitConnectionState(_connectionState);
    if (_authNotifier.isOnlineAuthenticated) {
      unawaited(_ensureConnected());
    }
  }

  /// Announces this installation to the account and returns the authoritative snapshot of the
  /// account's cast devices.
  ///
  /// The stable [CastDeviceRegistration.deviceId] is the identity; the SignalR connection is only
  /// where the server can reach it right now. Calling this again after a reconnect rebinds the same
  /// device instead of adding a second one.
  Future<CastDevicesSnapshot> registerCastDevice(
    CastDeviceRegistration registration,
  ) async {
    if (_isDisposed) {
      throw StateError('SyncHubService is already disposed');
    }
    if (registration.deviceId.trim().isEmpty ||
        registration.name.trim().isEmpty) {
      throw ArgumentError('Invalid cast device registration');
    }

    await _ensureConnected();
    final HubConnection? connection = _hubConnection;
    if (connection == null ||
        connection.state != HubConnectionState.Connected) {
      throw StateError('SignalR connection is not ready');
    }

    final Object? answer = await connection.invoke(
      'RegisterCastDevice',
      args: <Object>[registration.toJson()],
    );

    final CastDevicesSnapshot? snapshot = CastDevicesSnapshot.tryParse(answer);
    if (snapshot == null) {
      throw StateError('RegisterCastDevice returned an unreadable snapshot');
    }
    _emitCastDevices(snapshot);
    return snapshot;
  }

  /// Phase one of Handoff. Asks the API to have [receiverDeviceId] load [videoId].
  ///
  /// The position is deliberately absent: it travels with [commitCastSession] so that however long
  /// the Receiver takes, playback continues from where the viewer actually is.
  Future<CastSession> startCastSession({
    required String receiverDeviceId,
    required int videoId,
  }) async {
    final Object? answer = await _invokeCast(
      'StartCastSession',
      <String, Object?>{
        'receiverDeviceId': receiverDeviceId.trim(),
        'videoId': videoId,
      },
    );
    return _requireSession('StartCastSession', answer);
  }

  /// Phase two of Handoff: the latest absolute position and the playing/paused intent.
  Future<CastSession> commitCastSession({
    required String sessionId,
    required Duration position,
    required bool isPlaying,
  }) async {
    final Object? answer = await _invokeCast(
      'CommitCastSession',
      <String, Object?>{
        'sessionId': sessionId.trim(),
        'positionMs': position.isNegative ? 0 : position.inMilliseconds,
        'isPlaying': isPlaying,
      },
    );
    return _requireSession('CommitCastSession', answer);
  }

  /// The Receiver says it has the video loaded and is waiting for the commit.
  Future<CastSession> confirmCastPrepared({required String sessionId}) async {
    final Object? answer = await _invokeCast(
      'ConfirmCastPrepared',
      <String, Object?>{'sessionId': sessionId.trim()},
    );
    return _requireSession('ConfirmCastPrepared', answer);
  }

  /// The Receiver reports the playback state it is actually in.
  ///
  /// The first of these turns the session active and lets the phone release its local player; the
  /// ones that follow keep the phone up to date. It carries the whole state, so a phone that missed
  /// one converges on the next.
  ///
  /// The volume is held inside the player's range rather than refused here: it comes from this
  /// installation's own setting, and a report the API turned down would leave the phone showing
  /// nothing at all rather than showing something a rounding error away.
  Future<CastSession> reportCastPlaybackState({
    required String sessionId,
    required int videoId,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    required bool isBuffering,
    required bool isCompleted,
    required double volume,
    required int lastAppliedSeq,
  }) async {
    final Object? answer = await _invokeCast(
      'ReportCastPlaybackState',
      <String, Object?>{
        'sessionId': sessionId.trim(),
        'videoId': videoId,
        'positionMs': position.isNegative ? 0 : position.inMilliseconds,
        'durationMs': duration.isNegative ? 0 : duration.inMilliseconds,
        'isPlaying': isPlaying,
        'isBuffering': isBuffering,
        'isCompleted': isCompleted,
        'volume': PlayerVolume.normalise(volume),
        'lastAppliedSeq': lastAppliedSeq < 0 ? 0 : lastAppliedSeq,
      },
    );
    return _requireSession('ReportCastPlaybackState', answer);
  }

  /// Tells the Receiver to play or to pause.
  Future<CastSession> setCastPlaying({
    required String sessionId,
    required bool isPlaying,
  }) async {
    return _sendCastCommand(<String, Object?>{
      'sessionId': sessionId.trim(),
      'type': CastCommandType.setPlaying.wireValue,
      'isPlaying': isPlaying,
    });
  }

  /// Tells the Receiver to go to an absolute position.
  Future<CastSession> seekCastTo({
    required String sessionId,
    required Duration position,
  }) async {
    return _sendCastCommand(<String, Object?>{
      'sessionId': sessionId.trim(),
      'type': CastCommandType.seekTo.wireValue,
      'positionMs': position.isNegative ? 0 : position.inMilliseconds,
    });
  }

  /// Tells the Receiver to set the LocalTube player's volume.
  ///
  /// The value is held to the normalised range here rather than sent as it came: it arrives from a
  /// slider, and the API refuses anything outside the range rather than guessing what a viewer who
  /// dragged a fraction past the end meant.
  Future<CastSession> setCastVolume({
    required String sessionId,
    required double volume,
  }) async {
    return _sendCastCommand(<String, Object?>{
      'sessionId': sessionId.trim(),
      'type': CastCommandType.setVolume.wireValue,
      'volume': _normalisedVolume(volume),
    });
  }

  /// The player's volume range is 0 to 1 and the API refuses anything outside it, so a slider that
  /// went a fraction past the end is held to the range here rather than turned into a refusal.
  static double _normalisedVolume(double volume) {
    if (volume.isNaN || volume > 1) {
      return 1.0;
    }
    if (volume < 0) {
      return 0.0;
    }
    return volume;
  }

  Future<CastSession> _sendCastCommand(Map<String, Object?> payload) async {
    final Object? answer = await _invokeCast('SendCastCommand', payload);
    return _requireSession('SendCastCommand', answer);
  }

  /// Backs out of a Handoff that has not committed. The phone never gave up its local player, so
  /// the ended session that comes back is simply confirmation that nothing more will happen.
  Future<CastSession> cancelCastSession({required String sessionId}) async {
    final Object? answer = await _invokeCast(
      'CancelCastSession',
      <String, Object?>{'sessionId': sessionId.trim()},
    );
    return _requireSession('CancelCastSession', answer);
  }

  /// Return Handoff: stops the Receiver and ends the session, so playback continues here.
  ///
  /// The ended session that comes back still carries the last state the Receiver confirmed, which
  /// is the position this phone continues from.
  Future<CastSession> returnCastHandoff({required String sessionId}) async {
    final Object? answer = await _invokeCast(
      'ReturnCastHandoff',
      <String, Object?>{'sessionId': sessionId.trim()},
    );
    return _requireSession('ReturnCastHandoff', answer);
  }

  /// Ends the Cast Session this device takes part in, for a reason only this device can know.
  ///
  /// A blank [sessionId] means "whichever session I am in", which is what a device that is signing
  /// out wants. Nothing to end is an ordinary answer rather than a failure, and it arrives as a
  /// null payload, so a device on its way out is not handed an exception to deal with.
  Future<CastSession?> endCastSession({
    String? sessionId,
    required CastEndReason reason,
  }) async {
    final Object? answer = await _invokeCast(
      'EndCastSession',
      <String, Object?>{
        'sessionId': sessionId?.trim() ?? '',
        'reason': reason.wireValue,
      },
    );
    return CastSession.tryParse(answer);
  }

  /// What the API has for the session this device believes it is in.
  ///
  /// A session the API does not have - which is what a restarted API looks like - comes back ended
  /// with [CastEndReason.sessionMissing] rather than as a refusal, so the caller has something to
  /// act on and leaves cast state instead of holding a remote for nothing.
  Future<CastSession> resolveCastSession({required String sessionId}) async {
    final Object? answer = await _invokeCast(
      'ResolveCastSession',
      <String, Object?>{'sessionId': sessionId.trim()},
    );
    return _requireSession('ResolveCastSession', answer);
  }

  Future<Object?> _invokeCast(String method, Map<String, Object?> payload) async {
    if (_isDisposed) {
      throw StateError('SyncHubService is already disposed');
    }

    await _ensureConnected();
    final HubConnection? connection = _hubConnection;
    if (connection == null ||
        connection.state != HubConnectionState.Connected) {
      throw StateError('SignalR connection is not ready');
    }

    return connection.invoke(method, args: <Object>[payload]);
  }

  /// The answer to a session call goes back to the caller and is deliberately not also pushed onto
  /// [watchCastSession]: the stream carries what the API says on its own, so every session change
  /// is applied exactly once.
  CastSession _requireSession(String method, Object? answer) {
    final CastSession? session = CastSession.tryParse(answer);
    if (session == null) {
      throw StateError('$method returned an unreadable session');
    }
    return session;
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _authNotifier.removeListener(_onAuthStateChanged);
    await _disconnect(resetDevices: true);
    await _connectionStateController.close();
    await _castDevicesController.close();
    await _castSessionController.close();
    await _castPrepareController.close();
    await _castCommitController.close();
    await _castCommandController.close();
  }

  void _onAuthStateChanged() {
    if (_isDisposed) {
      return;
    }
    if (_authNotifier.isOnlineAuthenticated) {
      unawaited(_ensureConnected());
      return;
    }
    if (_authNotifier.accessMode == AppAccessMode.signedOut) {
      // Signing out is an explicit local action, not a network interruption, so a Cast Session
      // this device takes part in ends now rather than being given a minute to come back. It has
      // to be said before the connection goes, which is why it is here and not left to whatever
      // notices the connection has gone.
      //
      // Falling back to offline is deliberately not this: the account has not been put down and
      // the connection may be back in a moment, which is exactly what the reconnect window is for.
      unawaited(_signOut());
      return;
    }
    unawaited(_disconnect(resetDevices: true));
  }

  Future<void> _signOut() async {
    try {
      await endCastSession(reason: CastEndReason.participantSignedOut);
    } catch (error, stackTrace) {
      // A session that could not be ended is worth a log and nothing more: the connection is about
      // to go, and what is left of the session runs out its reconnect window on the server.
      _logService.error(
        'SyncHubService could not end the Cast Session on sign-out',
        error,
        stackTrace,
      );
    }
    await _disconnect(resetDevices: true);
  }

  Future<void> _ensureConnected() async {
    if (_isDisposed || _isConnecting || !_authNotifier.isOnlineAuthenticated) {
      return;
    }

    final HubConnection? connection = _hubConnection;
    final HubConnectionState? state = connection?.state;
    if (state == HubConnectionState.Connected ||
        state == HubConnectionState.Connecting ||
        state == HubConnectionState.Reconnecting) {
      return;
    }

    bool hasToken = false;
    try {
      hasToken = await _tokenRepository.hasAccessToken();
    } catch (error, stackTrace) {
      _logService.error('SyncHubService token probe failed', error, stackTrace);
      _emitConnectionState(SyncConnectionState.disconnected);
      return;
    }
    if (!hasToken) {
      _emitConnectionState(SyncConnectionState.disconnected);
      return;
    }

    _isConnecting = true;
    _emitConnectionState(SyncConnectionState.connecting);
    try {
      final HubConnection hubConnection = _hubConnection ?? _createConnection();
      _hubConnection = hubConnection;
      await hubConnection.start();
      _emitConnectionState(SyncConnectionState.connected);
    } catch (error, stackTrace) {
      _logService.error('SyncHubService start failed', error, stackTrace);
      _emitConnectionState(SyncConnectionState.disconnected);
    } finally {
      _isConnecting = false;
    }
  }

  HubConnection _createConnection() {
    final HubConnection connection = HubConnectionBuilder()
        .withUrl(
      _appConfig.signalrUrl,
      options: HttpConnectionOptions(
        requestTimeout: _appConfig.connectTimeoutMs,
        httpClient: _apiRoute.createSignalRClient(),
        transport: HttpTransportType.LongPolling,
        accessTokenFactory: () async {
          final session = await _tokenRepository.read();
          return session?.accessToken ?? '';
        },
      ),
    )
        .withAutomaticReconnect(
      retryDelays: <int>[0, 2000, 5000, 10000, 30000],
    ).build();

    connection.on('CastDevicesChanged', _onCastDevicesChangedEvent);
    connection.on('CastSessionChanged', _onCastSessionChangedEvent);
    connection.on('CastSessionPrepare', _onCastSessionPrepareEvent);
    connection.on('CastSessionCommit', _onCastSessionCommitEvent);
    connection.on('CastCommand', _onCastCommandEvent);
    connection.onreconnecting(({Exception? error}) {
      if (_isDisposed) {
        return;
      }
      _emitConnectionState(SyncConnectionState.reconnecting);
      if (error != null) {
        _logService.warn('SyncHubService reconnecting: $error');
      }
    });
    connection.onreconnected(({String? connectionId}) {
      if (_isDisposed) {
        return;
      }
      // A reconnect is a new routing address, so the server no longer has this device registered.
      // Until it registers again there is nothing authoritative to show.
      _emitCastDevices(CastDevicesSnapshot.empty);
      _emitConnectionState(SyncConnectionState.connected);
      _logService.info('SyncHubService reconnected: $connectionId');
    });
    connection.onclose(({Exception? error}) {
      if (_isDisposed) {
        return;
      }
      _emitCastDevices(CastDevicesSnapshot.empty);
      _emitConnectionState(SyncConnectionState.disconnected);
      if (error != null) {
        _logService.warn('SyncHubService closed: $error');
      }
    });
    return connection;
  }

  Future<void> _disconnect({required bool resetDevices}) async {
    final HubConnection? connection = _hubConnection;
    if (connection != null) {
      final HubConnectionState? state = connection.state;
      if (state != HubConnectionState.Disconnected &&
          state != HubConnectionState.Disconnecting) {
        try {
          await connection.stop();
        } catch (error, stackTrace) {
          _logService.error('SyncHubService stop failed', error, stackTrace);
        }
      }
    }

    if (resetDevices) {
      _emitCastDevices(CastDevicesSnapshot.empty);
    }
    _emitConnectionState(SyncConnectionState.disconnected);
  }

  void _onCastSessionChangedEvent(List<Object?>? arguments) {
    final CastSession? session = CastSession.tryParse(_argAt(arguments, 0));
    if (session == null) {
      _logService.warn('SyncHubService ignored an unreadable cast session');
      return;
    }
    _emitCastSession(session);
  }

  void _onCastSessionPrepareEvent(List<Object?>? arguments) {
    final CastPrepareCommand? command =
        CastPrepareCommand.tryParse(_argAt(arguments, 0));
    if (command == null) {
      _logService.warn('SyncHubService ignored an unreadable cast prepare');
      return;
    }
    if (!_castPrepareController.isClosed) {
      _castPrepareController.add(command);
    }
  }

  void _onCastSessionCommitEvent(List<Object?>? arguments) {
    final CastCommitCommand? command =
        CastCommitCommand.tryParse(_argAt(arguments, 0));
    if (command == null) {
      _logService.warn('SyncHubService ignored an unreadable cast commit');
      return;
    }
    if (!_castCommitController.isClosed) {
      _castCommitController.add(command);
    }
  }

  void _onCastCommandEvent(List<Object?>? arguments) {
    final CastCommand? command = CastCommand.tryParse(_argAt(arguments, 0));
    if (command == null) {
      // A command this version cannot read is not guessed at: the Receiver stays exactly as the
      // viewer last saw it rather than acting on an instruction nobody agreed the meaning of.
      _logService.warn('SyncHubService ignored an unreadable cast command');
      return;
    }
    if (!_castCommandController.isClosed) {
      _castCommandController.add(command);
    }
  }

  void _onCastDevicesChangedEvent(List<Object?>? arguments) {
    final CastDevicesSnapshot? snapshot =
        CastDevicesSnapshot.tryParse(_argAt(arguments, 0));
    if (snapshot == null) {
      _logService.warn('SyncHubService ignored an unreadable cast snapshot');
      return;
    }
    _emitCastDevices(snapshot);
  }

  Object? _argAt(List<Object?>? arguments, int index) {
    if (arguments == null || index < 0 || index >= arguments.length) {
      return null;
    }
    return arguments[index];
  }

  void _emitCastDevices(CastDevicesSnapshot snapshot) {
    _castDevices = snapshot;
    if (_castDevicesController.isClosed) {
      return;
    }
    _castDevicesController.add(snapshot);
  }

  void _emitCastSession(CastSession session) {
    if (_castSessionController.isClosed) {
      return;
    }
    _castSessionController.add(session);
  }

  void _emitConnectionState(SyncConnectionState state) {
    _connectionState = state;
    if (_connectionStateController.isClosed) {
      return;
    }
    _connectionStateController.add(state);
  }
}
