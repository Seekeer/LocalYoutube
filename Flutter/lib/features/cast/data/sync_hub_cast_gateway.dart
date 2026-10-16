import '../../sync/data/sync_hub_service.dart';
import '../../sync/domain/sync_models.dart';
import '../domain/cast_gateway.dart';
import '../domain/cast_models.dart';
import '../domain/cast_session_models.dart';

/// The Cast Session's view of the app's single SignalR connection.
///
/// There is one hub connection per installation and the cast protocol travels on it. This adapter
/// exists so that everything above it depends on [CastGateway] rather than on the hub service, its
/// play commands and its legacy client list.
class SyncHubCastGateway implements CastGateway {
  SyncHubCastGateway(this._syncHubService);

  final SyncHubService _syncHubService;

  @override
  SyncConnectionState get connectionState => _syncHubService.connectionState;

  @override
  Stream<SyncConnectionState> watchConnectionState() =>
      _syncHubService.watchConnectionState();

  @override
  CastDevicesSnapshot get devices => _syncHubService.castDevices;

  @override
  Stream<CastDevicesSnapshot> watchDevices() =>
      _syncHubService.watchCastDevices();

  @override
  Future<CastDevicesSnapshot> registerDevice(
    CastDeviceRegistration registration,
  ) =>
      _syncHubService.registerCastDevice(registration);

  @override
  Stream<CastSession> watchSession() => _syncHubService.watchCastSession();

  @override
  Future<CastSession> startSession({
    required String receiverDeviceId,
    required int videoId,
  }) =>
      _syncHubService.startCastSession(
        receiverDeviceId: receiverDeviceId,
        videoId: videoId,
      );

  @override
  Future<CastSession> commitSession({
    required String sessionId,
    required Duration position,
    required bool isPlaying,
  }) =>
      _syncHubService.commitCastSession(
        sessionId: sessionId,
        position: position,
        isPlaying: isPlaying,
      );

  @override
  Future<CastSession> setReceiverPlaying({
    required String sessionId,
    required bool isPlaying,
  }) =>
      _syncHubService.setCastPlaying(
        sessionId: sessionId,
        isPlaying: isPlaying,
      );

  @override
  Future<CastSession> seekReceiver({
    required String sessionId,
    required Duration position,
  }) =>
      _syncHubService.seekCastTo(sessionId: sessionId, position: position);

  @override
  Future<CastSession> setReceiverVolume({
    required String sessionId,
    required double volume,
  }) =>
      _syncHubService.setCastVolume(sessionId: sessionId, volume: volume);

  @override
  Stream<CastCommand> watchCommands() => _syncHubService.watchCastCommands();

  @override
  Future<CastSession> cancelSession({required String sessionId}) =>
      _syncHubService.cancelCastSession(sessionId: sessionId);

  @override
  Future<CastSession> returnHandoff({required String sessionId}) =>
      _syncHubService.returnCastHandoff(sessionId: sessionId);

  @override
  Future<CastSession?> endSession({
    String? sessionId,
    required CastEndReason reason,
  }) =>
      _syncHubService.endCastSession(sessionId: sessionId, reason: reason);

  @override
  Future<CastSession> resolveSession({required String sessionId}) =>
      _syncHubService.resolveCastSession(sessionId: sessionId);

  @override
  Stream<CastPrepareCommand> watchPrepareCommands() =>
      _syncHubService.watchCastPrepareCommands();

  @override
  Stream<CastCommitCommand> watchCommitCommands() =>
      _syncHubService.watchCastCommitCommands();

  @override
  Future<CastSession> confirmPrepared({required String sessionId}) =>
      _syncHubService.confirmCastPrepared(sessionId: sessionId);

  @override
  Future<CastSession> reportPlaybackState({
    required String sessionId,
    required int videoId,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    required bool isBuffering,
    required bool isCompleted,
    required double volume,
    required int lastAppliedSeq,
  }) =>
      _syncHubService.reportCastPlaybackState(
        sessionId: sessionId,
        videoId: videoId,
        position: position,
        duration: duration,
        isPlaying: isPlaying,
        isBuffering: isBuffering,
        isCompleted: isCompleted,
        volume: volume,
        lastAppliedSeq: lastAppliedSeq,
      );
}
