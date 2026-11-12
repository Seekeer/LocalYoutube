import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/player/presentation/player_keyboard_shortcuts.dart';
import 'package:localtube_flutter/features/player/presentation/player_stage_layout.dart';

KeyDownEvent _down(
  LogicalKeyboardKey logical, {
  PhysicalKeyboardKey physical = PhysicalKeyboardKey.keyA,
}) {
  return KeyDownEvent(
    physicalKey: physical,
    logicalKey: logical,
    timeStamp: Duration.zero,
  );
}

PlayerKeyAction? _resolve(
  KeyEvent event, {
  Set<LogicalKeyboardKey> modifiers = const <LogicalKeyboardKey>{},
  bool ownsFocus = true,
  bool isTextInputFocused = false,
  bool canExitFullscreen = false,
}) {
  return resolvePlayerKeyAction(
    event: event,
    pressedModifiers: modifiers,
    ownsFocus: ownsFocus,
    isTextInputFocused: isTextInputFocused,
    canExitFullscreen: canExitFullscreen,
  );
}

class _Harness {
  int toggles = 0;
  int fullscreenToggles = 0;
  int exits = 0;
  int buttonPresses = 0;
  final FocusNode playerFocus = FocusNode(debugLabel: 'player');
  final FocusNode buttonFocus = FocusNode(debugLabel: 'button');
  final FocusNode fieldFocus = FocusNode(debugLabel: 'field');

  Widget build({bool playbackEnabled = true, bool canExit = false}) {
    return MaterialApp(
      home: PlayerKeyboardShortcuts(
        focusNode: playerFocus,
        onTogglePlayback: playbackEnabled ? () => toggles++ : null,
        onToggleFullscreen: () => fullscreenToggles++,
        onExitFullscreen: canExit ? () => exits++ : null,
        child: Scaffold(
          body: Column(
            children: <Widget>[
              ElevatedButton(
                focusNode: buttonFocus,
                onPressed: () => buttonPresses++,
                child: const Text('Button'),
              ),
              TextField(focusNode: fieldFocus),
            ],
          ),
        ),
      ),
    );
  }

  void dispose() {
    playerFocus.dispose();
    buttonFocus.dispose();
    fieldFocus.dispose();
  }
}

Future<void> _pressCtrlF(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  group('resolvePlayerKeyAction', () {
    test('Ctrl+F toggles fullscreen', () {
      expect(
        _resolve(
          _down(LogicalKeyboardKey.keyF, physical: PhysicalKeyboardKey.keyF),
          modifiers: <LogicalKeyboardKey>{LogicalKeyboardKey.controlLeft},
        ),
        PlayerKeyAction.toggleFullscreen,
      );
    });

    test('Ctrl+F is the same physical key on a Russian layout', () {
      expect(
        _resolve(
          // The key labelled F types the Cyrillic "а" there.
          _down(const LogicalKeyboardKey(0x430), physical: PhysicalKeyboardKey.keyF),
          modifiers: <LogicalKeyboardKey>{LogicalKeyboardKey.controlRight},
        ),
        PlayerKeyAction.toggleFullscreen,
      );
    });

    test('F without Ctrl, AltGr+F and Ctrl+Shift+F are not the player\'s', () {
      final KeyDownEvent f = _down(
        LogicalKeyboardKey.keyF,
        physical: PhysicalKeyboardKey.keyF,
      );
      expect(_resolve(f), isNull);
      expect(
        _resolve(
          f,
          modifiers: <LogicalKeyboardKey>{
            LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.altRight,
          },
        ),
        isNull,
      );
      expect(
        _resolve(
          f,
          modifiers: <LogicalKeyboardKey>{
            LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.shiftLeft,
          },
        ),
        isNull,
      );
    });

    test('Ctrl+F works from a focused text field too', () {
      expect(
        _resolve(
          _down(LogicalKeyboardKey.keyF, physical: PhysicalKeyboardKey.keyF),
          modifiers: <LogicalKeyboardKey>{LogicalKeyboardKey.controlLeft},
          ownsFocus: false,
          isTextInputFocused: true,
        ),
        PlayerKeyAction.toggleFullscreen,
      );
    });

    test('Space plays or pauses only while the player holds the focus', () {
      final KeyDownEvent space = _down(LogicalKeyboardKey.space);
      expect(_resolve(space), PlayerKeyAction.togglePlayback);
      expect(_resolve(space, ownsFocus: false), isNull);
      expect(
        _resolve(
          space,
          modifiers: <LogicalKeyboardKey>{LogicalKeyboardKey.controlLeft},
        ),
        isNull,
      );
    });

    test('Escape leaves fullscreen only when there is one to leave', () {
      final KeyDownEvent escape = _down(LogicalKeyboardKey.escape);
      expect(_resolve(escape), isNull);
      expect(
        _resolve(escape, canExitFullscreen: true),
        PlayerKeyAction.exitFullscreen,
      );
    });

    test('a released key does nothing', () {
      expect(
        _resolve(
          const KeyUpEvent(
            physicalKey: PhysicalKeyboardKey.space,
            logicalKey: LogicalKeyboardKey.space,
            timeStamp: Duration.zero,
          ),
        ),
        isNull,
      );
    });
  });

  group('PlayerKeyboardShortcuts', () {
    late _Harness harness;

    setUp(() => harness = _Harness());
    tearDown(() => harness.dispose());

    testWidgets('Space plays or pauses once per press, however long it is held',
        (WidgetTester tester) async {
      await tester.pumpWidget(harness.build());
      await tester.pump();
      expect(harness.playerFocus.hasPrimaryFocus, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(harness.toggles, 1);
      expect(harness.buttonPresses, 0);
    });

    testWidgets('a focused button keeps its own Space and nothing plays',
        (WidgetTester tester) async {
      await tester.pumpWidget(harness.build());
      harness.buttonFocus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(harness.buttonPresses, 1);
      expect(harness.toggles, 0);
    });

    testWidgets(
        'a text field keeps Space but not Ctrl+F, and Space comes back to the player once it lets go',
        (WidgetTester tester) async {
      await tester.pumpWidget(harness.build());
      harness.fieldFocus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _pressCtrlF(tester);
      expect(harness.toggles, 0);
      expect(harness.fullscreenToggles, 1);

      harness.fieldFocus.unfocus();
      await tester.pump();
      expect(harness.playerFocus.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(harness.toggles, 1);
    });

    testWidgets('Ctrl+F works with a button focused and does not press it',
        (WidgetTester tester) async {
      await tester.pumpWidget(harness.build());
      harness.buttonFocus.requestFocus();
      await tester.pump();

      await _pressCtrlF(tester);

      expect(harness.fullscreenToggles, 1);
      expect(harness.buttonPresses, 0);
    });

    testWidgets('Escape leaves fullscreen only when the screen offers it',
        (WidgetTester tester) async {
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(harness.exits, 0);

      await tester.pumpWidget(harness.build(canExit: true));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(harness.exits, 1);
    });

    testWidgets('a disabled action leaves the key alone',
        (WidgetTester tester) async {
      await tester.pumpWidget(harness.build(playbackEnabled: false));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(harness.toggles, 0);
    });
  });

  group('PlayerStageLayout', () {
    Future<(Rect, Rect)> layOut(
      WidgetTester tester, {
      required double width,
      required double availableHeight,
      required double controlsHeight,
    }) async {
      const Key video = Key('video');
      const Key controls = Key('controls');
      tester.view.physicalSize = const Size(4000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: PlayerStageLayout(
                  availableHeight: availableHeight,
                  video: const AspectRatio(
                    key: video,
                    aspectRatio: 16 / 9,
                  ),
                  controls: SizedBox(key: controls, height: controlsHeight),
                ),
              ),
            ),
          ),
        ),
      );
      return (
        tester.getRect(find.byKey(video)),
        tester.getRect(find.byKey(controls)),
      );
    }

    testWidgets('the video takes the height the controls leave and stays 16:9',
        (WidgetTester tester) async {
      final (Rect video, Rect controls) = await layOut(
        tester,
        width: 1264,
        availableHeight: 640,
        controlsHeight: 260,
      );
      expect(video.height, 380);
      expect(video.width, closeTo(380 * 16 / 9, 0.01));
      // Centred across the width, with the controls straight under it.
      expect(video.center.dx, closeTo(1264 / 2, 0.01));
      expect(controls.top, video.bottom);
      expect(controls.bottom, 640);
    });

    testWidgets('a narrow window is limited by its width, not its height',
        (WidgetTester tester) async {
      final (Rect video, _) = await layOut(
        tester,
        width: 400,
        availableHeight: 900,
        controlsHeight: 260,
      );
      expect(video.width, 400);
      expect(video.height, closeTo(225, 0.01));
    });

    testWidgets('a very short window shrinks the video so the controls stay in it',
        (WidgetTester tester) async {
      final (Rect video, Rect controls) = await layOut(
        tester,
        width: 1264,
        availableHeight: 300,
        controlsHeight: 260,
      );
      expect(video.height, 40);
      expect(controls.bottom, 300);
    });

    testWidgets('a window shorter than the controls scrolls instead',
        (WidgetTester tester) async {
      final (Rect video, Rect controls) = await layOut(
        tester,
        width: 1264,
        availableHeight: 200,
        controlsHeight: 260,
      );
      expect(video.height, 0);
      expect(controls.height, 260);
    });

    testWidgets('a very tall window caps the video like the web player',
        (WidgetTester tester) async {
      final (Rect video, _) = await layOut(
        tester,
        width: 3000,
        availableHeight: 2000,
        controlsHeight: 260,
      );
      expect(video.height, 720);
    });
  });
}
