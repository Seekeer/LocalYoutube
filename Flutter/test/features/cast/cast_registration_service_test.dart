import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/cast/domain/cast_device_identity_service.dart';
import 'package:localtube_flutter/features/cast/domain/cast_models.dart';
import 'package:localtube_flutter/features/cast/domain/cast_registration_service.dart';
import 'package:localtube_flutter/features/cast/domain/cast_settings.dart';
import 'package:localtube_flutter/features/sync/domain/sync_models.dart';

import 'cast_doubles.dart';

void main() {
  test('a connected installation announces itself without being asked to',
      () async {
    final FakeCastGateway gateway = FakeCastGateway();
    final CastRegistrationService service = _buildService(
      gateway: gateway,
      model: 'Pixel 8',
    );
    addTearDown(service.dispose);
    addTearDown(gateway.close);

    await service.initialize();

    final CastDeviceRegistration registration =
        gateway.registrations.single;
    expect(registration.deviceId, 'device-1');
    expect(registration.name, 'Pixel 8');
    expect(registration.model, 'Pixel 8');
    expect(registration.role, CastDeviceRole.controller);
  });

  test('the role follows the persisted Receiver Mode setting', () async {
    final FakeCastGateway gateway = FakeCastGateway();
    final CastRegistrationService service = _buildService(
      gateway: gateway,
      settings: const CastSettings(
        isReceiverMode: true,
        deviceName: '',
        lastSelectedReceiverDeviceId: null,
      ),
      model: 'Pixel Tablet',
    );
    addTearDown(service.dispose);
    addTearDown(gateway.close);

    await service.initialize();

    expect(gateway.registrations.single.role, CastDeviceRole.receiver);
    expect(gateway.registrations.single.name, 'Pixel Tablet');
  });

  test('a chosen name is registered instead of the Android model', () async {
    final FakeCastGateway gateway = FakeCastGateway();
    final CastRegistrationService service = _buildService(
      gateway: gateway,
      settings: const CastSettings(
        isReceiverMode: true,
        deviceName: 'Living room',
        lastSelectedReceiverDeviceId: null,
      ),
      model: 'Pixel Tablet',
    );
    addTearDown(service.dispose);
    addTearDown(gateway.close);

    await service.initialize();

    expect(gateway.registrations.single.name, 'Living room');
    expect(gateway.registrations.single.model, 'Pixel Tablet');
  });

  test('a reconnect announces this device again', () async {
    final FakeCastGateway gateway = FakeCastGateway();
    final CastRegistrationService service = _buildService(gateway: gateway);
    addTearDown(service.dispose);
    addTearDown(gateway.close);

    await service.initialize();
    expect(gateway.registrations, hasLength(1));

    gateway.emitConnectionState(SyncConnectionState.reconnecting);
    gateway.emitConnectionState(SyncConnectionState.connected);
    await pumpEventQueue();

    // The server saw a brand new routing address and knows nothing about this device until it
    // registers again.
    expect(gateway.registrations, hasLength(2));
    expect(gateway.registrations.last.deviceId, 'device-1');
  });

  test('a changed setting is announced without waiting for a reconnect',
      () async {
    final FakeCastGateway gateway = FakeCastGateway();
    final InMemoryCastSettingsRepository settingsRepository =
        InMemoryCastSettingsRepository();
    final CastRegistrationService service = _buildService(
      gateway: gateway,
      settingsRepository: settingsRepository,
      model: 'Pixel Tablet',
    );
    addTearDown(service.dispose);
    addTearDown(gateway.close);

    await service.initialize();
    await settingsRepository.setReceiverMode(true);
    await settingsRepository.setDeviceName('Living room');
    await service.refresh();

    expect(gateway.registrations, hasLength(2));
    expect(gateway.registrations.last.role, CastDeviceRole.receiver);
    expect(gateway.registrations.last.name, 'Living room');
  });

  test('a disconnected installation still knows what it is', () async {
    final FakeCastGateway gateway = FakeCastGateway(
      connectionState: SyncConnectionState.disconnected,
    );
    final CastRegistrationService service = _buildService(
      gateway: gateway,
      model: 'Pixel Tablet',
    );
    addTearDown(service.dispose);
    addTearDown(gateway.close);

    await service.initialize();

    expect(gateway.registrations, isEmpty);
    expect(service.currentRegistration?.model, 'Pixel Tablet');
    expect(service.currentRegistration?.name, 'Pixel Tablet');
  });

  test('every change to what this device is reaches its watchers', () async {
    final FakeCastGateway gateway = FakeCastGateway();
    final InMemoryCastSettingsRepository settingsRepository =
        InMemoryCastSettingsRepository();
    final CastRegistrationService service = _buildService(
      gateway: gateway,
      settingsRepository: settingsRepository,
      model: 'Pixel Tablet',
    );
    addTearDown(service.dispose);
    addTearDown(gateway.close);

    final List<CastDeviceRole> observed = <CastDeviceRole>[];
    final StreamSubscription<CastDeviceRegistration> subscription =
        service.watchRegistration().listen(
              (CastDeviceRegistration registration) =>
                  observed.add(registration.role),
            );
    addTearDown(subscription.cancel);

    await service.initialize();
    await settingsRepository.setReceiverMode(true);
    await service.refresh();
    await pumpEventQueue();

    expect(
      observed,
      <CastDeviceRole>[CastDeviceRole.controller, CastDeviceRole.receiver],
    );
  });

  test('re-registering the very same description is not published twice',
      () async {
    final FakeCastGateway gateway = FakeCastGateway();
    final CastRegistrationService service = _buildService(gateway: gateway);
    addTearDown(service.dispose);
    addTearDown(gateway.close);

    await service.initialize();

    final List<CastDeviceRegistration> observed = <CastDeviceRegistration>[];
    final StreamSubscription<CastDeviceRegistration> subscription =
        service.watchRegistration().listen(observed.add);
    addTearDown(subscription.cancel);

    await service.refresh();
    await pumpEventQueue();

    expect(observed, isEmpty);
    expect(gateway.registrations, hasLength(2));
  });

  test('a hub that refuses the registration does not break the app', () async {
    final FakeCastGateway gateway = FakeCastGateway()
      ..registrationFailure = StateError('hub is not ready');
    final CastRegistrationService service = _buildService(gateway: gateway);
    addTearDown(service.dispose);
    addTearDown(gateway.close);

    await service.initialize();

    expect(gateway.registrations, isEmpty);
    expect(service.currentRegistration, isNotNull);
  });
}

CastRegistrationService _buildService({
  required FakeCastGateway gateway,
  InMemoryCastSettingsRepository? settingsRepository,
  CastSettings? settings,
  String model = 'Pixel 8',
  String deviceId = 'device-1',
}) {
  return CastRegistrationService(
    gateway: gateway,
    identityService: CastDeviceIdentityService(
      identityRepository: FixedCastDeviceIdentityRepository(deviceId),
      deviceModelSource: FakeDeviceModelSource(model),
    ),
    settingsRepository: settingsRepository ??
        InMemoryCastSettingsRepository(settings ?? CastSettings.defaults),
    logService: NoopLogService(),
  );
}
