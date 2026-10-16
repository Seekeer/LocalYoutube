import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

abstract interface class PlaybackScreenWakeLock {
  Future<void> setPlaying({
    required int videoId,
    required bool isPlaying,
  });
}

class AndroidPlaybackScreenWakeLock implements PlaybackScreenWakeLock {
  AndroidPlaybackScreenWakeLock._();

  static final AndroidPlaybackScreenWakeLock instance =
      AndroidPlaybackScreenWakeLock._();

  static const MethodChannel _channel = MethodChannel(
    'org.localtube.app/playback_screen_wake_lock',
  );

  final Set<int> _playingVideoIds = <int>{};
  Future<void>? _syncInProgress;
  bool _platformEnabled = false;

  bool get _supportsPlatform => Platform.isAndroid;

  @override
  Future<void> setPlaying({
    required int videoId,
    required bool isPlaying,
  }) {
    if (!_supportsPlatform) {
      return Future<void>.value();
    }

    if (isPlaying) {
      _playingVideoIds.add(videoId);
    } else {
      _playingVideoIds.remove(videoId);
    }

    final bool shouldEnable = _playingVideoIds.isNotEmpty;
    if (_syncInProgress == null && _platformEnabled == shouldEnable) {
      return Future<void>.value();
    }

    final Future<void>? currentSync = _syncInProgress;
    if (currentSync != null) {
      return currentSync;
    }

    final Future<void> nextSync = _synchronizePlatformState().whenComplete(() {
      _syncInProgress = null;
    });
    _syncInProgress = nextSync;
    return nextSync;
  }

  Future<void> _synchronizePlatformState() async {
    while (_platformEnabled != _playingVideoIds.isNotEmpty) {
      final bool enabled = _playingVideoIds.isNotEmpty;
      await _channel.invokeMethod<void>('setEnabled', <String, Object?>{
        'enabled': enabled,
      });
      _platformEnabled = enabled;
    }
  }
}
