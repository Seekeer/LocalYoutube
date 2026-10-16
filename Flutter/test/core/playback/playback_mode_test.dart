import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/network/network_status.dart';
import 'package:localtube_flutter/core/playback/playback_mode.dart';

void main() {
  test('effective mode is online by default', () {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        networkStatusProvider.overrideWith(
          (Ref ref) => Stream<NetworkStatus>.value(NetworkStatus.online),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(effectiveAutonomousModeProvider), isFalse);
  });

  test('manual mode forces local-only playback while network is online', () {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        manualAutonomousModeProvider.overrideWith((Ref ref) => true),
        networkStatusProvider.overrideWith(
          (Ref ref) => Stream<NetworkStatus>.value(NetworkStatus.online),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(effectiveAutonomousModeProvider), isTrue);
  });

  test('network offline forces local-only playback', () async {
    final StreamController<NetworkStatus> controller =
        StreamController<NetworkStatus>();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        networkStatusProvider.overrideWith((Ref ref) => controller.stream),
      ],
    );
    addTearDown(() async {
      await controller.close();
      container.dispose();
    });

    controller.add(NetworkStatus.offline);
    await container.read(networkStatusProvider.future);
    expect(container.read(effectiveAutonomousModeProvider), isTrue);
  });
}
