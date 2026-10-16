import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/storage/secure_storage_service.dart';
import 'package:localtube_flutter/features/cast/data/cast_device_identity_repository.dart';
import 'package:localtube_flutter/features/cast/data/device_model_source.dart';
import 'package:localtube_flutter/features/cast/domain/cast_device_identity_service.dart';
import 'package:localtube_flutter/features/cast/domain/cast_models.dart';

void main() {
  group('SecureCastDeviceIdentityRepository', () {
    test('generates a device id once and reuses it', () async {
      final _InMemorySecureStorageService storage =
          _InMemorySecureStorageService();
      final SecureCastDeviceIdentityRepository repository =
          SecureCastDeviceIdentityRepository(storage);

      final String first = await repository.deviceId();
      final String second = await repository.deviceId();

      expect(first, isNotEmpty);
      expect(second, first);
      expect(storage.writeCount, 1);
    });

    test('keeps the same device id across an app restart', () async {
      final _InMemorySecureStorageService storage =
          _InMemorySecureStorageService();

      final String beforeRestart =
          await SecureCastDeviceIdentityRepository(storage).deviceId();
      // A restart is a brand new repository over the same persisted storage.
      final String afterRestart =
          await SecureCastDeviceIdentityRepository(storage).deviceId();

      expect(afterRestart, beforeRestart);
      expect(storage.writeCount, 1);
    });

    test('concurrent first callers agree on one identity', () async {
      final _InMemorySecureStorageService storage =
          _InMemorySecureStorageService();
      final SecureCastDeviceIdentityRepository repository =
          SecureCastDeviceIdentityRepository(storage);

      final List<String> identities = await Future.wait<String>(<Future<String>>[
        repository.deviceId(),
        repository.deviceId(),
        repository.deviceId(),
      ]);

      expect(identities.toSet(), hasLength(1));
      expect(storage.writeCount, 1);
    });

    test('two installations do not share an identity', () async {
      final String first = await SecureCastDeviceIdentityRepository(
        _InMemorySecureStorageService(),
      ).deviceId();
      final String second = await SecureCastDeviceIdentityRepository(
        _InMemorySecureStorageService(),
      ).deviceId();

      expect(first, isNot(second));
    });

    test('still yields an identity when storage cannot be read or written',
        () async {
      final _FailingSecureStorageService storage =
          _FailingSecureStorageService();
      final SecureCastDeviceIdentityRepository repository =
          SecureCastDeviceIdentityRepository(storage);

      final String first = await repository.deviceId();
      final String second = await repository.deviceId();

      expect(first, isNotEmpty);
      expect(second, first);
    });

    test('generates a 32 character hexadecimal identity', () async {
      final SecureCastDeviceIdentityRepository repository =
          SecureCastDeviceIdentityRepository(
        _InMemorySecureStorageService(),
        random: Random(1),
      );

      final String identity = await repository.deviceId();

      expect(identity, matches(RegExp(r'^[0-9a-f]{32}$')));
    });
  });

  group('CastDeviceIdentityService', () {
    test('registers stable identity, name, model and the requested role',
        () async {
      final CastDeviceIdentityService service = CastDeviceIdentityService(
        identityRepository: _FixedIdentityRepository('device-1'),
        deviceModelSource: _FakeDeviceModelSource('Pixel Tablet'),
      );

      final CastDeviceRegistration registration = await service.describe(
        role: CastDeviceRole.receiver,
        preferredName: 'Living room',
      );

      expect(registration.deviceId, 'device-1');
      expect(registration.name, 'Living room');
      expect(registration.model, 'Pixel Tablet');
      expect(registration.role, CastDeviceRole.receiver);
    });

    test('names a device after its android model until it is renamed',
        () async {
      final CastDeviceIdentityService service = CastDeviceIdentityService(
        identityRepository: _FixedIdentityRepository('device-1'),
        deviceModelSource: _FakeDeviceModelSource('Pixel Tablet'),
      );

      final CastDeviceRegistration registration =
          await service.describe(role: CastDeviceRole.receiver);

      expect(registration.name, 'Pixel Tablet');
    });

    test('falls back to a generic name when the platform reports no model',
        () async {
      final CastDeviceIdentityService service = CastDeviceIdentityService(
        identityRepository: _FixedIdentityRepository('device-1'),
        deviceModelSource: _FakeDeviceModelSource('  '),
      );

      final CastDeviceRegistration registration = await service.describe(
        role: CastDeviceRole.controller,
        preferredName: '   ',
      );

      expect(registration.name, CastDeviceIdentityService.fallbackName);
      expect(registration.model, '');
      expect(registration.role, CastDeviceRole.controller);
    });

    test('a failing model channel does not fail registration', () async {
      final CastDeviceIdentityService service = CastDeviceIdentityService(
        identityRepository: _FixedIdentityRepository('device-1'),
        deviceModelSource: _ThrowingDeviceModelSource(),
      );

      final CastDeviceRegistration registration =
          await service.describe(role: CastDeviceRole.receiver);

      expect(registration.model, '');
      expect(registration.name, CastDeviceIdentityService.fallbackName);
    });
  });
}

class _InMemorySecureStorageService extends SecureStorageService {
  _InMemorySecureStorageService() : _store = <String, String>{};

  final Map<String, String> _store;

  int writeCount = 0;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
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

class _FailingSecureStorageService extends SecureStorageService {
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

class _FixedIdentityRepository implements CastDeviceIdentityRepository {
  _FixedIdentityRepository(this._deviceId);

  final String _deviceId;

  @override
  Future<String> deviceId() async => _deviceId;
}

class _FakeDeviceModelSource implements DeviceModelSource {
  _FakeDeviceModelSource(this._model);

  final String _model;

  @override
  Future<String> androidModel() async => _model;
}

class _ThrowingDeviceModelSource implements DeviceModelSource {
  @override
  Future<String> androidModel() async =>
      throw StateError('no platform channel in a test');
}
