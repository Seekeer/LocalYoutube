import 'dart:io';

import 'package:fvp/fvp.dart';
import 'package:video_player/video_player.dart';

/// Native subtitle selection is available on the Windows FVP backend.
class PlayerSubtitles {
  bool hasTracks(VideoPlayerController controller) => Platform.isWindows &&
      controller.value.isInitialized &&
      (controller.getMediaInfo()?.subtitle?.isNotEmpty ?? false);

  void apply(VideoPlayerController controller, {required bool enabled}) {
    if (!Platform.isWindows) return;
    final tracks = controller.getMediaInfo()?.subtitle;
    controller.setSubtitleTracks(
      enabled && tracks != null && tracks.isNotEmpty
          ? <int>[0]
          : <int>[],
    );
  }
}
