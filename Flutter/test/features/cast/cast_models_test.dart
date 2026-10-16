import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/cast/domain/cast_models.dart';

/// The payloads here are the shape observed against the real hub in
/// `src/Api.IntegrationTests/CastProtocolWireFormatTests.cs`: camelCase property names and
/// lower-case role values. They are decoded from JSON text rather than written as Dart maps so the
/// test exercises the same `Map<String, dynamic>` the SignalR client hands over.
void main() {
  group('CastDeviceRole', () {
    test('maps roles to the values the API uses', () {
      expect(CastDeviceRole.controller.wireValue, 'controller');
      expect(CastDeviceRole.receiver.wireValue, 'receiver');
    });

    test('parses a known role in any casing', () {
      expect(CastDeviceRole.tryParse('receiver'), CastDeviceRole.receiver);
      expect(CastDeviceRole.tryParse(' Controller '), CastDeviceRole.controller);
    });

    test('refuses an unknown role instead of guessing', () {
      expect(CastDeviceRole.tryParse('television'), isNull);
      expect(CastDeviceRole.tryParse(''), isNull);
      expect(CastDeviceRole.tryParse(null), isNull);
      expect(CastDeviceRole.tryParse(7), isNull);
    });
  });

  group('CastDeviceRegistration', () {
    test('registers as the device the account then reads back', () {
      const CastDeviceRegistration registration = CastDeviceRegistration(
        deviceId: 'tv-1',
        name: 'Living room',
        model: 'Pixel Tablet',
        role: CastDeviceRole.receiver,
      );

      // The hub answers a registration with the account's devices, so what this installation
      // writes is what it reads back a moment later. The wire format itself - the property names
      // and the role casing - is pinned against the real socket by
      // `Registration_accepts_the_camel_case_payload_the_flutter_client_sends` in
      // `src/Api.IntegrationTests/CastProtocolWireFormatTests.cs`, which is the better boundary
      // for it; what matters here is that the two halves of this file agree.
      final CastDevice? echoed = CastDevice.tryParse(
        _decode(jsonEncode(registration.toJson())),
      );

      expect(echoed, isNotNull);
      expect(echoed!.deviceId, 'tv-1');
      expect(echoed.name, 'Living room');
      expect(echoed.model, 'Pixel Tablet');
      expect(echoed.role, CastDeviceRole.receiver);
    });

    test('a role this client does not know survives no round trip', () {
      const CastDeviceRegistration registration = CastDeviceRegistration(
        deviceId: 'tv-1',
        name: 'Living room',
        model: 'Pixel Tablet',
        role: CastDeviceRole.receiver,
      );

      // A device whose role is not one of the two this version knows is dropped rather than
      // guessed at, so a future role cannot be offered as a cast target by accident.
      final Map<String, Object?> payload = registration.toJson();
      payload['role'] = 'television';

      expect(CastDevice.tryParse(_decode(jsonEncode(payload))), isNull);
    });
  });

  group('CastDevicesSnapshot', () {
    test('parses the snapshot the hub sends', () {
      final CastDevicesSnapshot? snapshot = CastDevicesSnapshot.tryParse(
        _decode('''
        {
          "devices": [
            {
              "deviceId": "tv-1",
              "name": "Living room",
              "model": "Pixel Tablet",
              "role": "receiver"
            },
            {
              "deviceId": "phone-1",
              "name": "Pixel 8",
              "model": "Pixel 8",
              "role": "controller"
            }
          ]
        }
        '''),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.devices, hasLength(2));
      expect(snapshot.devices.first.deviceId, 'tv-1');
      expect(snapshot.devices.first.name, 'Living room');
      expect(snapshot.devices.first.model, 'Pixel Tablet');
      expect(snapshot.devices.first.role, CastDeviceRole.receiver);
      expect(snapshot.receivers.map((CastDevice device) => device.deviceId),
          <String>['tv-1']);
    });

    test('reads an empty account as an empty snapshot', () {
      final CastDevicesSnapshot? snapshot =
          CastDevicesSnapshot.tryParse(_decode('{"devices": []}'));

      expect(snapshot, isNotNull);
      expect(snapshot!.devices, isEmpty);
      expect(snapshot, CastDevicesSnapshot.empty);
    });

    test('drops a device it cannot make sense of instead of the whole snapshot',
        () {
      final CastDevicesSnapshot? snapshot = CastDevicesSnapshot.tryParse(
        _decode('''
        {
          "devices": [
            {"deviceId": "tv-1", "name": "Living room", "model": "M", "role": "receiver"},
            {"deviceId": "tv-2", "name": "Bedroom", "model": "M", "role": "television"},
            {"deviceId": "", "name": "Nameless", "model": "M", "role": "receiver"},
            "not a device"
          ]
        }
        '''),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.devices.map((CastDevice device) => device.deviceId),
          <String>['tv-1']);
    });

    test('names a device after its model when the hub sent no name', () {
      final CastDevicesSnapshot? snapshot = CastDevicesSnapshot.tryParse(
        _decode(
          '{"devices": [{"deviceId": "tv-1", "name": "", "model": "Pixel Tablet", "role": "receiver"}]}',
        ),
      );

      expect(snapshot!.devices.single.name, 'Pixel Tablet');
    });

    test('refuses a payload that is not a snapshot', () {
      expect(CastDevicesSnapshot.tryParse(null), isNull);
      expect(CastDevicesSnapshot.tryParse('devices'), isNull);
      expect(CastDevicesSnapshot.tryParse(_decode('{"other": []}')), isNull);
      expect(CastDevicesSnapshot.tryParse(_decode('[]')), isNull);
    });
  });
}

Object? _decode(String json) {
  final Object? decoded = jsonDecode(json);
  return decoded;
}
