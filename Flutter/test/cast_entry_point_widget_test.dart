import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/cast/domain/cast_device_labels.dart';
import 'package:localtube_flutter/features/cast/domain/cast_models.dart';
import 'package:localtube_flutter/features/cast/domain/cast_session_models.dart';
import 'package:localtube_flutter/features/cast/domain/cast_settings.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_controller.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_entry_point.dart';
import 'package:localtube_flutter/features/sync/domain/sync_models.dart';

import 'features/cast/cast_doubles.dart';

class MockCastController extends StateNotifier<CastUiState>
    implements CastController {
  MockCastController(super.state);

  final List<String?> selectedReceivers = <String?>[];
  final List<bool> receiverModeChanges = <bool>[];
  final List<String> renames = <String>[];
  final List<int> startedCasts = <int>[];
  int cancelledCasts = 0;

  @override
  Future<void> get initialized async {}

  @override
  Future<void> setReceiverMode(bool isReceiverMode) async {
    receiverModeChanges.add(isReceiverMode);
  }

  @override
  Future<void> renameDevice(String name) async {
    renames.add(name);
  }

  @override
  Future<void> selectReceiver(String? deviceId) async {
    selectedReceivers.add(deviceId);
  }

  @override
  Future<void> startCast({required int videoId}) async {
    startedCasts.add(videoId);
  }

  @override
  Future<void> cancelCast() async {
    cancelledCasts++;
  }

  @override
  Future<void> returnHandoff() async {}

  @override
  Future<void> setReceiverPlaying(bool isPlaying) async {}

  @override
  Future<void> seekReceiver(Duration position) async {}

  @override
  Future<void> setReceiverVolume(double volume) async {}
}

CastUiState stateWith({
  List<CastDevice> receivers = const <CastDevice>[],
  String? selectedReceiverDeviceId,
  bool isReceiverMode = false,
  String deviceName = 'Pixel 8',
  String deviceModel = 'Pixel 8',
  SyncConnectionState connectionState = SyncConnectionState.connected,
  CastPhase phase = CastPhase.idle,
  String? castFailureReason,
}) {
  return CastUiState(
    isReceiverMode: isReceiverMode,
    deviceName: deviceName,
    deviceModel: deviceModel,
    receivers: labelCastDevices(receivers),
    selectedReceiverDeviceId: selectedReceiverDeviceId,
    connectionState: connectionState,
    phase: phase,
    castFailureReason: castFailureReason,
  );
}

CastDevice receiver({
  required String deviceId,
  required String name,
  String model = 'Pixel Tablet',
}) {
  return CastDevice(
    deviceId: deviceId,
    name: name,
    model: model,
    role: CastDeviceRole.receiver,
  );
}

Widget buildEntryPoint(CastController controller, {int? videoId}) {
  return ProviderScope(
    overrides: <Override>[
      castControllerProvider.overrideWith((ref) => controller),
    ],
    child: MaterialApp(
      home: Scaffold(body: CastEntryPoint(videoId: videoId)),
    ),
  );
}

void main() {
  testWidgets('the Cast entry point stays visible with no Receiver online',
      (WidgetTester tester) async {
    final MockCastController controller = MockCastController(stateWith());

    await tester.pumpWidget(buildEntryPoint(controller));
    await tester.pumpAndSettle();

    expect(find.text(CastEntryPoint.title), findsOneWidget);
    expect(find.byKey(CastEntryPoint.noReceiversMessageKey), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('the empty state says how to make a Receiver available',
      (WidgetTester tester) async {
    final MockCastController controller = MockCastController(stateWith());

    await tester.pumpWidget(buildEntryPoint(controller));
    await tester.pumpAndSettle();

    expect(CastEntryPoint.noReceiversMessage, contains('LocalTube'));
    expect(
      CastEntryPoint.noReceiversMessage,
      contains('the device you want to watch on'),
    );
    expect(CastEntryPoint.noReceiversMessage, contains('Receiver Mode'));
    expect(find.text(CastEntryPoint.noReceiversMessage), findsOneWidget);
  });

  testWidgets('online Receivers are listed and duplicates are told apart',
      (WidgetTester tester) async {
    final MockCastController controller = MockCastController(
      stateWith(
        receivers: <CastDevice>[
          receiver(deviceId: 'tv-1', name: 'Living room', model: 'Shield TV'),
          receiver(
            deviceId: 'tv-2',
            name: 'Living room',
            model: 'Pixel Tablet',
          ),
          receiver(deviceId: 'tv-3', name: 'Bedroom'),
        ],
      ),
    );

    await tester.pumpWidget(buildEntryPoint(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(CastEntryPoint.noReceiversMessageKey), findsNothing);
    expect(find.text('Living room'), findsNWidgets(2));
    expect(find.text('Shield TV'), findsOneWidget);
    expect(find.text('Pixel Tablet'), findsOneWidget);
    // A name nobody else uses needs no qualifier.
    expect(find.text('Bedroom'), findsOneWidget);
    expect(find.byKey(CastEntryPoint.receiverKey('tv-3')), findsOneWidget);
  });

  testWidgets('the preselected Receiver is the only one marked',
      (WidgetTester tester) async {
    final MockCastController controller = MockCastController(
      stateWith(
        receivers: <CastDevice>[
          receiver(deviceId: 'tv-1', name: 'Living room'),
          receiver(deviceId: 'tv-2', name: 'Bedroom'),
        ],
        selectedReceiverDeviceId: 'tv-2',
      ),
    );

    await tester.pumpWidget(buildEntryPoint(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(CastEntryPoint.selectedReceiverKey), findsOneWidget);
    final ListTile selectedTile = tester.widget<ListTile>(
      find.byKey(CastEntryPoint.receiverKey('tv-2')),
    );
    expect(selectedTile.selected, isTrue);
    final ListTile otherTile = tester.widget<ListTile>(
      find.byKey(CastEntryPoint.receiverKey('tv-1')),
    );
    expect(otherTile.selected, isFalse);
  });

  testWidgets('nothing is marked while the remembered Receiver is offline',
      (WidgetTester tester) async {
    final MockCastController controller = MockCastController(
      stateWith(
        receivers: <CastDevice>[
          receiver(deviceId: 'tv-1', name: 'Living room'),
        ],
      ),
    );

    await tester.pumpWidget(buildEntryPoint(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(CastEntryPoint.selectedReceiverKey), findsNothing);
  });

  // The two below are driven by a real Cast Controller over the fake API connection, because what
  // they are about is the rule that decides the list rather than the way a list is drawn: which
  // Receivers the account has online right now, and whether the remembered one is among them.

  testWidgets('the remembered Receiver is not preselected while it is offline',
      (WidgetTester tester) async {
    final CastControllerHarness harness = await CastControllerHarness.start(
      settings: const CastSettings(
        isReceiverMode: false,
        deviceName: '',
        lastSelectedReceiverDeviceId: 'tv-1',
      ),
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      buildEntryPoint(harness.controller, videoId: 42),
    );
    harness.gateway.emitDevices(<CastDevice>[
      receiver(deviceId: 'tv-2', name: 'Bedroom'),
    ]);
    await tester.pumpAndSettle();

    // The remembered Receiver is not in the account's snapshot, so nothing is marked and there is
    // nothing to cast to.
    expect(find.byKey(CastEntryPoint.receiverKey('tv-2')), findsOneWidget);
    expect(find.byKey(CastEntryPoint.selectedReceiverKey), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(CastEntryPoint.castButtonKey))
          .onPressed,
      isNull,
    );

    // It is remembered rather than forgotten: it is marked again by itself the moment it appears
    // in a snapshot.
    harness.gateway.emitDevices(<CastDevice>[
      receiver(deviceId: 'tv-2', name: 'Bedroom'),
      receiver(deviceId: 'tv-1', name: 'Living room'),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(CastEntryPoint.selectedReceiverKey), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(CastEntryPoint.receiverKey('tv-1')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(CastEntryPoint.castButtonKey))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('closing LocalTube on the Receiver takes it off the list',
      (WidgetTester tester) async {
    final CastControllerHarness harness = await CastControllerHarness.start();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      buildEntryPoint(harness.controller, videoId: 42),
    );
    harness.gateway.emitDevices(<CastDevice>[
      receiver(deviceId: 'tv-1', name: 'Living room'),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(CastEntryPoint.receiverKey('tv-1')), findsOneWidget);
    expect(find.text('Living room'), findsOneWidget);
    expect(find.byKey(CastEntryPoint.noReceiversMessageKey), findsNothing);

    // LocalTube being closed on the Receiver is simply its absence from the next snapshot the API
    // pushes: a Receiver is available only while the application is open on it.
    harness.gateway.emitDevices(const <CastDevice>[]);
    await tester.pumpAndSettle();

    expect(find.byKey(CastEntryPoint.receiverKey('tv-1')), findsNothing);
    expect(find.text('Living room'), findsNothing);
    expect(find.byKey(CastEntryPoint.noReceiversMessageKey), findsOneWidget);
  });

  testWidgets('picking a Receiver records the choice and starts no cast',
      (WidgetTester tester) async {
    final MockCastController controller = MockCastController(
      stateWith(
        receivers: <CastDevice>[
          receiver(deviceId: 'tv-1', name: 'Living room'),
        ],
      ),
    );

    await tester.pumpWidget(buildEntryPoint(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(CastEntryPoint.receiverKey('tv-1')));
    await tester.pumpAndSettle();

    expect(controller.selectedReceivers, <String?>['tv-1']);
    // The entry point offers no way to start playing on the Receiver yet.
    expect(find.widgetWithText(FilledButton, 'Cast'), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('the Cast action hands the current video over', (
    WidgetTester tester,
  ) async {
    final MockCastController controller = MockCastController(
      stateWith(
        receivers: <CastDevice>[
          receiver(deviceId: 'tv-1', name: 'Living room'),
        ],
        selectedReceiverDeviceId: 'tv-1',
      ),
    );

    await tester.pumpWidget(buildEntryPoint(controller, videoId: 42));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(CastEntryPoint.castButtonKey));
    await tester.pumpAndSettle();

    expect(controller.startedCasts, <int>[42]);
    // Starting a cast is not the same as picking one, and does not pick again.
    expect(controller.selectedReceivers, isEmpty);
  });

  testWidgets('there is nothing to start until a Receiver is picked', (
    WidgetTester tester,
  ) async {
    final MockCastController controller = MockCastController(
      stateWith(
        receivers: <CastDevice>[
          receiver(deviceId: 'tv-1', name: 'Living room'),
        ],
      ),
    );

    await tester.pumpWidget(buildEntryPoint(controller, videoId: 42));
    await tester.pumpAndSettle();

    final FilledButton button = tester.widget<FilledButton>(
      find.byKey(CastEntryPoint.castButtonKey),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the phone says the television is being prepared', (
    WidgetTester tester,
  ) async {
    final MockCastController controller = MockCastController(
      stateWith(
        receivers: <CastDevice>[
          receiver(deviceId: 'tv-1', name: 'Living room'),
        ],
        selectedReceiverDeviceId: 'tv-1',
        phase: CastPhase.preparing,
      ),
    );

    await tester.pumpWidget(buildEntryPoint(controller, videoId: 42));
    await tester.pumpAndSettle();

    expect(find.byKey(CastEntryPoint.preparingKey), findsOneWidget);
    // Nothing can be started twice.
    final FilledButton button = tester.widget<FilledButton>(
      find.byKey(CastEntryPoint.castButtonKey),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a television that is taking too long can be backed out of', (
    WidgetTester tester,
  ) async {
    final MockCastController controller = MockCastController(
      stateWith(
        receivers: <CastDevice>[
          receiver(deviceId: 'tv-1', name: 'Living room'),
        ],
        selectedReceiverDeviceId: 'tv-1',
        phase: CastPhase.preparing,
      ),
    );

    await tester.pumpWidget(buildEntryPoint(controller, videoId: 42));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(CastEntryPoint.cancelButtonKey));
    await tester.pumpAndSettle();

    expect(controller.cancelledCasts, 1);
    // Backing out is not starting: the viewer stays exactly where they were.
    expect(controller.startedCasts, isEmpty);
  });

  testWidgets('there is nothing to back out of until a cast is under way', (
    WidgetTester tester,
  ) async {
    final MockCastController controller = MockCastController(
      stateWith(
        receivers: <CastDevice>[
          receiver(deviceId: 'tv-1', name: 'Living room'),
        ],
        selectedReceiverDeviceId: 'tv-1',
      ),
    );

    await tester.pumpWidget(buildEntryPoint(controller, videoId: 42));
    await tester.pumpAndSettle();

    expect(find.byKey(CastEntryPoint.cancelButtonKey), findsNothing);
  });

  testWidgets('a refused cast is explained rather than silently dropped', (
    WidgetTester tester,
  ) async {
    final MockCastController controller = MockCastController(
      stateWith(
        receivers: <CastDevice>[
          receiver(deviceId: 'tv-1', name: 'Living room'),
        ],
        selectedReceiverDeviceId: 'tv-1',
        castFailureReason: CastErrorReason.sessionAlreadyActive,
      ),
    );

    await tester.pumpWidget(buildEntryPoint(controller, videoId: 42));
    await tester.pumpAndSettle();

    expect(find.byKey(CastEntryPoint.failureKey), findsOneWidget);
    expect(find.text(CastEntryPoint.alreadyCastingMessage), findsOneWidget);
  });

  testWidgets('a refusal this version does not know still says so', (
    WidgetTester tester,
  ) async {
    final MockCastController controller = MockCastController(
      stateWith(
        receivers: <CastDevice>[
          receiver(deviceId: 'tv-1', name: 'Living room'),
        ],
        selectedReceiverDeviceId: 'tv-1',
        castFailureReason: CastErrorReason.unrecognised,
      ),
    );

    await tester.pumpWidget(buildEntryPoint(controller, videoId: 42));
    await tester.pumpAndSettle();

    expect(find.text(CastEntryPoint.castFailedMessage), findsOneWidget);
  });
}
