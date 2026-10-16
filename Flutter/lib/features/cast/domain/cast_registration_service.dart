import 'dart:async';

import '../../../core/logging/log_service.dart';
import '../../sync/domain/sync_models.dart';
import '../data/cast_settings_repository.dart';
import 'cast_device_identity_service.dart';
import 'cast_gateway.dart';
import 'cast_models.dart';
import 'cast_settings.dart';

/// Keeps this installation announced to its account for as long as it is connected.
///
/// Registering is not something a person does. A connected installation says who it is - its stable
/// identity, its current name, its Android model and the role its persisted Receiver Mode setting
/// asks for - and says it again on every reconnect, because a reconnect gives the server a new
/// routing address and no memory of this device.
///
/// It also says it again whenever the name or Receiver Mode changes, which is what makes the other
/// devices' lists follow a rename or a device being switched into Receiver Mode without anyone
/// reconnecting.
class CastRegistrationService {
  CastRegistrationService({
    required CastGateway gateway,
    required CastDeviceIdentityService identityService,
    required CastSettingsRepository settingsRepository,
    required LogService logService,
  })  : _gateway = gateway,
        _identityService = identityService,
        _settingsRepository = settingsRepository,
        _logService = logService;

  final CastGateway _gateway;
  final CastDeviceIdentityService _identityService;
  final CastSettingsRepository _settingsRepository;
  final LogService _logService;

  final StreamController<CastDeviceRegistration> _registrationController =
      StreamController<CastDeviceRegistration>.broadcast();

  StreamSubscription<SyncConnectionState>? _connectionSubscription;
  CastDeviceRegistration? _currentRegistration;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isRegistering = false;
  bool _registerAgain = false;

  /// What this installation currently says it is, or `null` before it has worked that out.
  ///
  /// It is known even while offline: describing the device costs nothing, and the settings screen
  /// has to show the name and model before a connection exists.
  CastDeviceRegistration? get currentRegistration => _currentRegistration;

  /// Every change to [currentRegistration].
  Stream<CastDeviceRegistration> watchRegistration() =>
      _registrationController.stream;

  /// Starts registering on every connect, and works out what this device is straight away. Calling
  /// it twice does nothing the second time.
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) {
      return;
    }
    _isInitialized = true;
    _connectionSubscription = _gateway.watchConnectionState().listen(
      (SyncConnectionState connectionState) {
        if (connectionState == SyncConnectionState.connected) {
          unawaited(refresh());
        }
      },
    );
    await refresh();
  }

  /// Describes this installation again and announces it if there is a connection to announce it on.
  ///
  /// Call it after Receiver Mode or the name changed. While offline it still refreshes what this
  /// device says it is, and the next connect announces that.
  Future<void> refresh() async {
    if (_isDisposed) {
      return;
    }
    if (_isRegistering) {
      // A change that lands mid-registration must not be lost behind the one in flight.
      _registerAgain = true;
      return;
    }

    _isRegistering = true;
    try {
      do {
        _registerAgain = false;
        await _registerOnce();
      } while (_registerAgain && !_isDisposed);
    } finally {
      _isRegistering = false;
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _registrationController.close();
  }

  Future<void> _registerOnce() async {
    final CastDeviceRegistration registration;
    try {
      final CastSettings settings = await _settingsRepository.read();
      registration = await _identityService.describe(
        role: settings.isReceiverMode
            ? CastDeviceRole.receiver
            : CastDeviceRole.controller,
        preferredName: settings.deviceName,
      );
    } catch (error, stackTrace) {
      _logService.error(
        'CastRegistrationService could not describe this device',
        error,
        stackTrace,
      );
      return;
    }

    _publish(registration);

    if (_gateway.connectionState != SyncConnectionState.connected) {
      // There is nobody to announce this to yet. The next connect announces whatever is current
      // then, which is why a failure here is not worth retrying.
      return;
    }

    try {
      await _gateway.registerDevice(registration);
    } catch (error, stackTrace) {
      _logService.error(
        'CastRegistrationService registration failed',
        error,
        stackTrace,
      );
    }
  }

  void _publish(CastDeviceRegistration registration) {
    if (_currentRegistration == registration) {
      return;
    }
    _currentRegistration = registration;
    if (!_registrationController.isClosed) {
      _registrationController.add(registration);
    }
  }
}
