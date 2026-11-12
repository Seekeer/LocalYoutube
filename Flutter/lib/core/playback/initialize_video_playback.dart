import 'package:video_player_media_kit/video_player_media_kit.dart';

/// Supply the desktop backend before creating any video_player controllers.
/// Android and iOS continue using their existing platform implementations.
void initializeVideoPlayback() {
  VideoPlayerMediaKit.ensureInitialized(windows: true);
}
