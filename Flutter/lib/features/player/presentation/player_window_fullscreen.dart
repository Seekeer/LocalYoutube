import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The application window's own fullscreen, for the player's fullscreen route.
///
/// On Android the route's immersive system UI mode is the whole of fullscreen. On Windows that
/// mode does nothing: the window keeps its title bar, its frame and the taskbar, so the route alone
/// is just the same window without the page's controls. There the Windows runner switches the
/// window itself to borderless fullscreen on its current monitor, and back to the exact frame,
/// position and maximized state it had before.
class PlayerWindowFullscreen {
  const PlayerWindowFullscreen._();

  /// Served by the Windows runner (`windows/runner/flutter_window.cpp`).
  static const MethodChannel channel = MethodChannel(
    'org.localtube.app/window',
  );

  /// Whether this platform's window takes part in the player's fullscreen.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Puts the window into fullscreen or takes it out again. Asking for the state the window is
  /// already in does nothing.
  ///
  /// A window that cannot change is not an error worth stopping the player for: the fullscreen
  /// route still shows the video, only inside the ordinary window.
  static Future<void> setFullScreen(bool fullScreen) async {
    if (!isSupported) {
      return;
    }
    try {
      await channel.invokeMethod<bool>('setFullScreen', fullScreen);
    } on MissingPluginException {
      // A runner without the channel (an older build or a test) keeps its ordinary window.
    } on PlatformException catch (error) {
      debugPrint('Window fullscreen failed: ${error.code} ${error.message}');
    }
  }
}
