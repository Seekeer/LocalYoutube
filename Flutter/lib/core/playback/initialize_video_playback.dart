import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// The pinned adapter has no public backend configuration or export.
// ignore: implementation_imports
import 'package:video_player_media_kit/src/media_kit_video_player.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Supply the desktop backend before creating any video_player controllers.
/// Android and iOS continue using their existing platform implementations.
void initializeVideoPlayback() {
  if (!Platform.isWindows) return;
  VideoPlayerMediaKit.ensureInitialized(windows: true);
  VideoPlayerPlatform.instance = _WindowsMediaKitVideoPlayer();
}

class _WindowsMediaKitVideoPlayer extends MediaKitVideoPlayer {
  @override
  Stream<VideoEvent> videoEventsFor(int textureId) =>
      filterWindowsVideoEvents(super.videoEventsFor(textureId));
}

/// libmpv falls back to software decoding when no hardware device is available.
/// The adapter forwards that diagnostic as a fatal PlatformException even after
/// decoding a frame. Preserve other errors so invalid sources still fail.
Stream<VideoEvent> filterWindowsVideoEvents(Stream<VideoEvent> events) =>
    events.handleError((Object error) {
      debugPrint(
          'Windows video: hardware decoder unavailable; using software decoding.');
    },
        test: (Object? error) =>
            error is PlatformException &&
            error.message?.trim() == 'Failed to allocate AVHWDeviceContext.');
