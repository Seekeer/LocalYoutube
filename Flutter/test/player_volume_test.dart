import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/player/domain/player_volume.dart';
import 'package:localtube_flutter/features/player/presentation/player_volume_control.dart';

class _MemoryVolumeStore implements PlayerVolumeStore {
  PlayerVolumeSetting? setting;
  final List<PlayerVolumeSetting> writes = <PlayerVolumeSetting>[];
  bool failReads = false;

  @override
  Future<PlayerVolumeSetting?> read() async {
    if (failReads) {
      throw const FileSystemException('unreadable');
    }
    return setting;
  }

  @override
  Future<void> write(PlayerVolumeSetting setting) async {
    writes.add(setting);
    this.setting = setting;
  }
}

void main() {
  group('PlayerVolume', () {
    test('muting keeps the level and unmuting brings it back', () {
      final PlayerVolume volume = PlayerVolume(level: 0.6);

      volume.toggleMuted();
      expect(volume.isMuted, isTrue);
      expect(volume.value, 0.0);
      expect(volume.level, 0.6);

      volume.toggleMuted();
      expect(volume.isMuted, isFalse);
      expect(volume.value, 0.6);
    });

    test('moving the volume unmutes and is held to the range', () {
      final PlayerVolume volume = PlayerVolume(isMuted: true);

      expect(volume.setValue(0.3), 0.3);
      expect(volume.isMuted, isFalse);
      expect(volume.setValue(4), 1.0);
      expect(volume.setValue(-1), 0.0);
      expect(volume.setValue(double.nan), 1.0);
    });

    test('unmuting a level turned all the way down makes it audible', () {
      final PlayerVolume volume = PlayerVolume(level: 0);
      expect(volume.isSilent, isTrue);

      volume.toggleMuted();

      expect(volume.value, PlayerVolume.unmuteLevel);
      expect(volume.isMuted, isFalse);
    });

    test('listeners hear every change and nothing else', () {
      final PlayerVolume volume = PlayerVolume(level: 0.5);
      int changes = 0;
      volume.addListener(() => changes++);

      volume.setValue(0.5);
      volume.setMuted(false);
      expect(changes, 0);

      volume.setValue(0.8);
      volume.setMuted(true);
      expect(changes, 2);
    });

    test('is remembered between launches', () async {
      final _MemoryVolumeStore store = _MemoryVolumeStore();
      final PlayerVolume first = await PlayerVolume.load(store);
      expect(first.value, 1.0);

      first.setValue(0.35);
      first.setMuted(true);
      await first.flush();

      final PlayerVolume next = await PlayerVolume.load(store);
      expect(next.level, 0.35);
      expect(next.isMuted, isTrue);
    });

    test('a burst of changes writes only the newest, never two at once', () async {
      final _MemoryVolumeStore store = _MemoryVolumeStore();
      final PlayerVolume volume = PlayerVolume(store: store);

      for (int step = 1; step <= 10; step++) {
        volume.setValue(step / 10);
      }
      await volume.flush();

      expect(store.writes, hasLength(1));
      expect(store.writes.single.level, 1.0);
    });

    test('a store it cannot read starts at full volume', () async {
      final _MemoryVolumeStore store = _MemoryVolumeStore()..failReads = true;

      final PlayerVolume volume = await PlayerVolume.load(store);

      expect(volume.value, 1.0);
      expect(volume.isMuted, isFalse);
    });
  });

  group('FilePlayerVolumeStore', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('player-volume-test');
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('writes, overwrites and reads the setting back', () async {
      final FilePlayerVolumeStore store =
          FilePlayerVolumeStore(directory: () async => directory);
      expect(await store.read(), isNull);

      await store.write(const PlayerVolumeSetting(level: 0.25, isMuted: false));
      await store.write(const PlayerVolumeSetting(level: 0.75, isMuted: true));

      final PlayerVolumeSetting? setting = await store.read();
      expect(setting?.level, 0.75);
      expect(setting?.isMuted, isTrue);
    });

    test('a damaged file reads as nothing remembered', () async {
      await File(
        '${directory.path}${Platform.pathSeparator}${FilePlayerVolumeStore.fileName}',
      ).writeAsString('{not json');
      final FilePlayerVolumeStore store =
          FilePlayerVolumeStore(directory: () async => directory);

      expect(await store.read(), isNull);
    });
  });

  group('PlayerVolumeControl', () {
    Future<PlayerVolume> pumpControl(WidgetTester tester, PlayerVolume volume) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: PlayerVolumeControl(volume: volume)),
          ),
        ),
      );
      return volume;
    }

    testWidgets('the mute button silences and brings the sound back',
        (WidgetTester tester) async {
      final PlayerVolume volume = await pumpControl(tester, PlayerVolume(level: 0.6));
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byTooltip('Без звука'), findsOneWidget);

      await tester.tap(find.byKey(PlayerVolumeControl.muteButtonKey));
      await tester.pump();
      expect(volume.isMuted, isTrue);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      expect(find.byTooltip('Включить звук'), findsOneWidget);
      expect(
        tester.widget<Slider>(find.byKey(PlayerVolumeControl.sliderKey)).value,
        0.0,
      );

      await tester.tap(find.byKey(PlayerVolumeControl.muteButtonKey));
      await tester.pump();
      expect(volume.value, 0.6);
    });

    testWidgets('dragging the slider sets the volume and unmutes',
        (WidgetTester tester) async {
      final PlayerVolume volume =
          await pumpControl(tester, PlayerVolume(level: 1.0, isMuted: true));

      final Finder slider = find.byKey(PlayerVolumeControl.sliderKey);
      final Rect track = tester.getRect(slider);
      await tester.tapAt(Offset(track.left + track.width * 0.25, track.center.dy));
      await tester.pump();

      expect(volume.isMuted, isFalse);
      expect(volume.level, closeTo(0.25, 0.15));
      expect(find.byIcon(Icons.volume_down), findsOneWidget);
    });

    testWidgets('follows a change made elsewhere, such as a Cast Session',
        (WidgetTester tester) async {
      final PlayerVolume volume = await pumpControl(tester, PlayerVolume(level: 0.9));

      volume.setValue(0.2);
      await tester.pump();

      expect(
        tester.widget<Slider>(find.byKey(PlayerVolumeControl.sliderKey)).value,
        0.2,
      );
    });
  });
}
