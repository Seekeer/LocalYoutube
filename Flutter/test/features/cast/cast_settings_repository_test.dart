import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/storage/secure_storage_service.dart';
import 'package:localtube_flutter/features/cast/data/cast_settings_repository.dart';
import 'package:localtube_flutter/features/cast/domain/cast_settings.dart';

void main() {
  test('an installation that was never configured is an ordinary Controller',
      () async {
    final CastSettings settings =
        await SecureCastSettingsRepository(_InMemorySecureStorage()).read();

    expect(settings, CastSettings.defaults);
    expect(settings.isReceiverMode, isFalse);
  });

  test('Receiver Mode survives an app restart', () async {
    final _InMemorySecureStorage storage = _InMemorySecureStorage();

    await SecureCastSettingsRepository(storage).setReceiverMode(true);
    // A restart is a brand new repository over the same persisted storage.
    final CastSettings afterRestart =
        await SecureCastSettingsRepository(storage).read();

    expect(afterRestart.isReceiverMode, isTrue);
  });

  test('turning Receiver Mode back off survives an app restart too', () async {
    final _InMemorySecureStorage storage = _InMemorySecureStorage();

    await SecureCastSettingsRepository(storage).setReceiverMode(true);
    await SecureCastSettingsRepository(storage).setReceiverMode(false);

    final CastSettings afterRestart =
        await SecureCastSettingsRepository(storage).read();
    expect(afterRestart.isReceiverMode, isFalse);
  });

  test('a chosen name survives an app restart and a blank name clears it',
      () async {
    final _InMemorySecureStorage storage = _InMemorySecureStorage();

    await SecureCastSettingsRepository(storage).setDeviceName('  Living room ');
    expect(
      (await SecureCastSettingsRepository(storage).read()).deviceName,
      'Living room',
    );

    await SecureCastSettingsRepository(storage).setDeviceName('   ');
    expect(
      (await SecureCastSettingsRepository(storage).read()).deviceName,
      '',
    );
    expect(
      storage.containsKey(SecureCastSettingsRepository.deviceNameKey),
      isFalse,
    );
  });

  test('the last selected Receiver is remembered and can be forgotten',
      () async {
    final _InMemorySecureStorage storage = _InMemorySecureStorage();

    await SecureCastSettingsRepository(storage).setLastSelectedReceiver('tv-1');
    expect(
      (await SecureCastSettingsRepository(storage).read())
          .lastSelectedReceiverDeviceId,
      'tv-1',
    );

    await SecureCastSettingsRepository(storage).setLastSelectedReceiver(null);
    expect(
      (await SecureCastSettingsRepository(storage).read())
          .lastSelectedReceiverDeviceId,
      isNull,
    );
  });

  test('settings are kept under their own stable keys', () async {
    final _InMemorySecureStorage storage = _InMemorySecureStorage();
    final SecureCastSettingsRepository repository =
        SecureCastSettingsRepository(storage);

    await repository.setReceiverMode(true);
    await repository.setDeviceName('Living room');
    await repository.setLastSelectedReceiver('tv-1');

    expect(
      storage.read(SecureCastSettingsRepository.receiverModeKey),
      completion('true'),
    );
    expect(
      storage.read(SecureCastSettingsRepository.deviceNameKey),
      completion('Living room'),
    );
    expect(
      storage.read(SecureCastSettingsRepository.lastSelectedReceiverKey),
      completion('tv-1'),
    );
  });

  test('one repository answers every reader without re-reading storage',
      () async {
    final _InMemorySecureStorage storage = _InMemorySecureStorage();
    final SecureCastSettingsRepository repository =
        SecureCastSettingsRepository(storage);

    await Future.wait<CastSettings>(<Future<CastSettings>>[
      repository.read(),
      repository.read(),
      repository.read(),
    ]);

    expect(storage.readCount, 3);
  });

  test('unreadable storage still describes an ordinary Controller', () async {
    final CastSettings settings =
        await SecureCastSettingsRepository(_FailingSecureStorage()).read();

    expect(settings, CastSettings.defaults);
  });

  test('a failed write still holds for the current run', () async {
    final SecureCastSettingsRepository repository =
        SecureCastSettingsRepository(_FailingSecureStorage());

    final CastSettings settings = await repository.setReceiverMode(true);

    expect(settings.isReceiverMode, isTrue);
    expect((await repository.read()).isReceiverMode, isTrue);
  });
}

class _InMemorySecureStorage extends SecureStorageService {
  _InMemorySecureStorage() : _store = <String, String>{};

  final Map<String, String> _store;

  int readCount = 0;

  bool containsKey(String key) => _store.containsKey(key);

  @override
  Future<String?> read(String key) async {
    readCount++;
    return _store[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }
}

class _FailingSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async =>
      throw StateError('secure storage unavailable');

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('secure storage unavailable');

  @override
  Future<void> delete(String key) async =>
      throw StateError('secure storage unavailable');

  @override
  Future<void> deleteAll() async =>
      throw StateError('secure storage unavailable');
}
