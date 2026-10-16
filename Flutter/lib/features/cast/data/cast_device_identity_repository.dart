import 'dart:math';

import '../../../core/storage/secure_storage_service.dart';

/// The installation's stable Cast Session identity.
///
/// A LocalTube installation is one device for as long as it is installed: the identity is generated
/// once, persisted, and reused across reconnects and app restarts. The SignalR connection id is not
/// an identity - it changes on every reconnect, which is exactly what would make one Receiver look
/// like a new one each time.
abstract interface class CastDeviceIdentityRepository {
  /// The stable device identity, generating and persisting it on first use.
  Future<String> deviceId();
}

class SecureCastDeviceIdentityRepository implements CastDeviceIdentityRepository {
  SecureCastDeviceIdentityRepository(
    this._storage, {
    Random? random,
  }) : _random = random ?? Random.secure();

  /// Key in secure storage. Renaming it would hand every installed client a new identity.
  static const String deviceIdKey = 'cast_device_id';

  static const int _deviceIdBytes = 16;

  final SecureStorageService _storage;
  final Random _random;

  String? _cached;
  Future<String>? _pending;

  @override
  Future<String> deviceId() {
    final String? cached = _cached;
    if (cached != null) {
      return Future<String>.value(cached);
    }
    // Two callers racing on first use must not end up with two identities.
    return _pending ??= _resolve();
  }

  Future<String> _resolve() async {
    try {
      final String? stored = await _storage.read(deviceIdKey);
      if (stored != null && stored.trim().isNotEmpty) {
        final String identity = stored.trim();
        _cached = identity;
        return identity;
      }
    } catch (_) {
      // Unreadable storage must not keep the app from casting: a fresh identity is generated
      // below and persisted if the write succeeds.
    }

    final String generated = _generate();
    try {
      await _storage.write(deviceIdKey, generated);
    } catch (_) {
      // The identity still holds for this run; the next run generates another one.
    }
    _cached = generated;
    return generated;
  }

  String _generate() {
    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < _deviceIdBytes; index++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
