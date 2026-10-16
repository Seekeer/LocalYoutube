import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/cast/domain/cast_models.dart';
import 'package:localtube_flutter/features/cast/domain/cast_settings.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_controller.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_settings_page.dart';

import 'features/cast/cast_doubles.dart';

/// The settings screen over a real Cast Controller.
///
/// Receiver Mode and the device name are the Cast Controller's answers, not this screen's: the name
/// a device that has never been renamed carries is worked out in
/// `CastDeviceIdentityService.resolveName` from the Android model, and clearing the name clears the
/// choice in the settings repository rather than writing the model into it. A mock controller
/// answering with a name of the test's own making would say nothing about any of that.
Widget buildSettingsPage(CastController controller) {
  return ProviderScope(
    overrides: <Override>[
      castControllerProvider.overrideWith((ref) => controller),
    ],
    child: const MaterialApp(home: CastSettingsPage()),
  );
}

/// A device that has been made a Receiver and has never been renamed.
const CastSettings _newReceiver = CastSettings(
  isReceiverMode: true,
  deviceName: '',
  lastSelectedReceiverDeviceId: null,
);

void main() {
  testWidgets('Receiver Mode is shown as the persisted setting it is',
      (WidgetTester tester) async {
    final CastControllerHarness harness = await CastControllerHarness.start(
      settings: _newReceiver,
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(buildSettingsPage(harness.controller));
    await tester.pumpAndSettle();

    expect(find.text(CastSettingsPage.receiverModeTitle), findsOneWidget);
    final SwitchListTile switchTile = tester.widget<SwitchListTile>(
      find.byKey(CastSettingsPage.receiverModeSwitchKey),
    );
    expect(switchTile.value, isTrue);
  });

  testWidgets('turning Receiver Mode on asks for it to be persisted',
      (WidgetTester tester) async {
    final CastControllerHarness harness = await CastControllerHarness.start();
    addTearDown(harness.dispose);

    await tester.pumpWidget(buildSettingsPage(harness.controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(CastSettingsPage.receiverModeSwitchKey));
    await tester.pumpAndSettle();

    expect(harness.settingsRepository.settings.isReceiverMode, isTrue);
    final SwitchListTile switchTile = tester.widget<SwitchListTile>(
      find.byKey(CastSettingsPage.receiverModeSwitchKey),
    );
    expect(switchTile.value, isTrue);
    // And the account hears the new role, so the other devices' lists follow it without anyone
    // reconnecting.
    expect(harness.gateway.registrations.last.role, CastDeviceRole.receiver);
  });

  testWidgets('the name field starts at the Android model of a new Receiver',
      (WidgetTester tester) async {
    final CastControllerHarness harness = await CastControllerHarness.start(
      settings: _newReceiver,
      model: 'Pixel Tablet',
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(buildSettingsPage(harness.controller));
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(
      find.byKey(CastSettingsPage.deviceNameFieldKey),
    );
    expect(field.controller?.text, 'Pixel Tablet');
    // Nobody chose that name. It is what this installation is called until somebody does, on the
    // screen and in what the account is told, which is the same answer in both places.
    expect(harness.settingsRepository.settings.deviceName, isEmpty);
    expect(harness.gateway.registrations.last.name, 'Pixel Tablet');
  });

  testWidgets('the name can be edited', (WidgetTester tester) async {
    final CastControllerHarness harness = await CastControllerHarness.start(
      settings: _newReceiver,
      model: 'Pixel Tablet',
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(buildSettingsPage(harness.controller));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(CastSettingsPage.deviceNameFieldKey),
      'Living room',
    );
    await tester.tap(find.byKey(CastSettingsPage.saveNameButtonKey));
    await tester.pumpAndSettle();

    expect(harness.settingsRepository.settings.deviceName, 'Living room');
    expect(harness.gateway.registrations.last.name, 'Living room');
    final TextField field = tester.widget<TextField>(
      find.byKey(CastSettingsPage.deviceNameFieldKey),
    );
    expect(field.controller?.text, 'Living room');
  });

  testWidgets('clearing the name falls back to the Android model',
      (WidgetTester tester) async {
    final CastControllerHarness harness = await CastControllerHarness.start(
      settings: const CastSettings(
        isReceiverMode: true,
        deviceName: 'Living room',
        lastSelectedReceiverDeviceId: null,
      ),
      model: 'Pixel Tablet',
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(buildSettingsPage(harness.controller));
    await tester.pumpAndSettle();
    final TextField field = tester.widget<TextField>(
      find.byKey(CastSettingsPage.deviceNameFieldKey),
    );
    expect(field.controller?.text, 'Living room');

    await tester.enterText(
      find.byKey(CastSettingsPage.deviceNameFieldKey),
      '',
    );
    await tester.tap(find.byKey(CastSettingsPage.saveNameButtonKey));
    await tester.pumpAndSettle();

    // An empty name is the choice being cleared rather than the model being written into it, so
    // the device is named after its model again - here, and in what the account is told.
    expect(harness.settingsRepository.settings.deviceName, isEmpty);
    expect(harness.gateway.registrations.last.name, 'Pixel Tablet');
    expect(
      tester
          .widget<TextField>(find.byKey(CastSettingsPage.deviceNameFieldKey))
          .controller
          ?.text,
      'Pixel Tablet',
    );
  });
}
