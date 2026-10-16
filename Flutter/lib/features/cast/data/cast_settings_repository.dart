import '../../../core/storage/secure_storage_service.dart';
import '../domain/cast_settings.dart';

/// Where this installation's cast choices are kept.
///
/// Behind an interface so the Cast Controller can be tested without storage, and so the storage can
/// move later without touching anything above it.
abstract interface class CastSettingsRepository {
  /// The current settings, defaulting every value that was never written.
  Future<CastSettings> read();

  /// Turns Receiver Mode on or off and returns the settings as they now stand.
  Future<CastSettings> setReceiverMode(bool isReceiverMode);

  /// Renames this installation. A blank name clears the choice, which puts the Android device model
  /// back in its place.
  Future<CastSettings> setDeviceName(String deviceName);

  /// Remembers the Receiver the person picked, or forgets it when given `null`.
  Future<CastSettings> setLastSelectedReceiver(String? deviceId);
}

/// Cast settings in secure storage, next to the installation's stable cast identity.
///
/// Secure storage is what this app already has for values that must outlive the process and must
/// not be wiped by a sign-out: signing out deletes named token keys, never the whole store. The
/// drift `session_meta` table would not do, because it is cleared with the session, and Receiver
/// Mode is a property of the installation rather than of whoever is signed in.
class SecureCastSettingsRepository implements CastSettingsRepository {
  SecureCastSettingsRepository(this._storage);

  /// Renaming any of these keys hands every installed client its factory defaults back.
  static const String receiverModeKey = 'cast_receiver_mode';
  static const String deviceNameKey = 'cast_device_name';
  static const String lastSelectedReceiverKey = 'cast_last_receiver_id';

  static const String _trueValue = 'true';

  final SecureStorageService _storage;

  CastSettings? _cached;
  Future<CastSettings>? _pending;

  @override
  Future<CastSettings> read() {
    final CastSettings? cached = _cached;
    if (cached != null) {
      return Future<CastSettings>.value(cached);
    }
    // Two callers racing on first use must read the store once and agree on the answer.
    return _pending ??= _load();
  }

  @override
  Future<CastSettings> setReceiverMode(bool isReceiverMode) async {
    final CastSettings current = await read();
    final CastSettings next = current.copyWith(isReceiverMode: isReceiverMode);
    _cached = next;
    await _write(receiverModeKey, isReceiverMode ? _trueValue : 'false');
    return next;
  }

  @override
  Future<CastSettings> setDeviceName(String deviceName) async {
    final CastSettings current = await read();
    final String trimmed = deviceName.trim();
    final CastSettings next = current.copyWith(deviceName: trimmed);
    _cached = next;
    if (trimmed.isEmpty) {
      await _delete(deviceNameKey);
    } else {
      await _write(deviceNameKey, trimmed);
    }
    return next;
  }

  @override
  Future<CastSettings> setLastSelectedReceiver(String? deviceId) async {
    final CastSettings current = await read();
    final String trimmed = deviceId?.trim() ?? '';
    final CastSettings next = trimmed.isEmpty
        ? current.copyWith(clearLastSelectedReceiver: true)
        : current.copyWith(lastSelectedReceiverDeviceId: trimmed);
    _cached = next;
    if (trimmed.isEmpty) {
      await _delete(lastSelectedReceiverKey);
    } else {
      await _write(lastSelectedReceiverKey, trimmed);
    }
    return next;
  }

  Future<CastSettings> _load() async {
    CastSettings settings = CastSettings.defaults;
    try {
      final String? storedReceiverMode = await _storage.read(receiverModeKey);
      final String? storedName = await _storage.read(deviceNameKey);
      final String? storedReceiver =
          await _storage.read(lastSelectedReceiverKey);

      final String trimmedReceiver = storedReceiver?.trim() ?? '';
      settings = CastSettings(
        isReceiverMode:
            storedReceiverMode?.trim().toLowerCase() == _trueValue,
        deviceName: storedName?.trim() ?? '',
        lastSelectedReceiverDeviceId:
            trimmedReceiver.isEmpty ? null : trimmedReceiver,
      );
    } catch (_) {
      // Unreadable storage must not keep the app from working: the defaults describe an ordinary
      // Controller, which is the safe thing to be.
    }
    _cached = settings;
    return settings;
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key, value);
    } catch (_) {
      // The choice still holds for this run; it simply will not survive a restart.
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key);
    } catch (_) {
      // Same as a failed write: the in-memory value is already correct.
    }
  }
}
