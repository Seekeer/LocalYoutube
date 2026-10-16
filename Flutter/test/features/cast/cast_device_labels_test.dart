import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/cast/domain/cast_device_labels.dart';
import 'package:localtube_flutter/features/cast/domain/cast_models.dart';

import 'cast_doubles.dart';

void main() {
  test('a name nobody else uses stands on its own', () {
    final List<CastDeviceLabel> labels = labelCastDevices(<CastDevice>[
      castDevice(deviceId: 'tv-1', name: 'Living room'),
      castDevice(deviceId: 'tv-2', name: 'Bedroom', model: 'Chromecast'),
    ]);

    expect(labels.map((CastDeviceLabel label) => label.name),
        <String>['Living room', 'Bedroom']);
    expect(labels.every((CastDeviceLabel label) => label.detail == null), isTrue);
    expect(labels.first.displayLabel, 'Living room');
  });

  test('two Receivers sharing a name are told apart by model', () {
    final List<CastDeviceLabel> labels = labelCastDevices(<CastDevice>[
      castDevice(deviceId: 'tv-1', name: 'Living room', model: 'Pixel Tablet'),
      castDevice(deviceId: 'tv-2', name: 'Living room', model: 'Shield TV'),
    ]);

    expect(labels[0].detail, 'Pixel Tablet');
    expect(labels[1].detail, 'Shield TV');
    expect(labels[0].displayLabel, 'Living room (Pixel Tablet)');
  });

  test('a short identity suffix appears only when the model is not enough', () {
    final List<CastDeviceLabel> labels = labelCastDevices(<CastDevice>[
      castDevice(deviceId: 'aaaa1111', name: 'Living room', model: 'Shield TV'),
      castDevice(deviceId: 'bbbb2222', name: 'Living room', model: 'Shield TV'),
      castDevice(deviceId: 'cccc3333', name: 'Living room', model: 'Pixel Tablet'),
    ]);

    expect(labels[0].detail, 'Shield TV #1111');
    expect(labels[1].detail, 'Shield TV #2222');
    // The third one is the only Shield-less device of that name, so it needs no identity at all.
    expect(labels[2].detail, 'Pixel Tablet');
  });

  test('a viewer never has to read a full identity to tell devices apart', () {
    const String first = '0123456789abcdef0123456789abcdef';
    const String second = 'fedcba9876543210fedcba9876543210';

    final List<CastDeviceLabel> labels = labelCastDevices(<CastDevice>[
      castDevice(deviceId: first, name: 'Living room', model: 'Shield TV'),
      castDevice(deviceId: second, name: 'Living room', model: 'Shield TV'),
    ]);

    expect(labels[0].detail, 'Shield TV #cdef');
    expect(labels[1].detail, 'Shield TV #3210');
    expect(labels[0].detail, isNot(contains(first)));
  });

  test('the suffix grows until it separates identities that share a tail', () {
    final List<CastDeviceLabel> labels = labelCastDevices(<CastDevice>[
      castDevice(deviceId: 'a1beef', name: 'Living room', model: 'Shield TV'),
      castDevice(deviceId: 'b2beef', name: 'Living room', model: 'Shield TV'),
    ]);

    expect(labels[0].detail, 'Shield TV #1beef');
    expect(labels[1].detail, 'Shield TV #2beef');
  });

  test('a device with no model falls back to the identity suffix alone', () {
    final List<CastDeviceLabel> labels = labelCastDevices(<CastDevice>[
      castDevice(deviceId: 'aaaa1111', name: 'Living room', model: ''),
      castDevice(deviceId: 'bbbb2222', name: 'Living room', model: ''),
    ]);

    expect(labels[0].detail, '#1111');
    expect(labels[1].detail, '#2222');
  });

  test('labelling keeps the order the API reported', () {
    final List<CastDeviceLabel> labels = labelCastDevices(<CastDevice>[
      castDevice(deviceId: 'tv-2', name: 'Zed'),
      castDevice(deviceId: 'tv-1', name: 'Alpha'),
    ]);

    expect(
      labels.map((CastDeviceLabel label) => label.deviceId),
      <String>['tv-2', 'tv-1'],
    );
  });

  test('an empty snapshot labels nothing', () {
    expect(labelCastDevices(const <CastDevice>[]), isEmpty);
  });
}
