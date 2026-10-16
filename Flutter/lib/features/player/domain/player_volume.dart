import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The LocalTube player's own volume on this installation.
///
/// It is the app's media volume and never the Android system volume: changing it affects what
/// LocalTube plays and nothing else on the device, so a viewer casting to a Receiver cannot turn
/// down its alarms or anyone else's music.
///
/// It lives here rather than inside a player because it belongs to the installation and not to any
/// one video. A player controller is built for a video and thrown away with it, while a device
/// is expected to sound the same from one video to the next - and a Receiver in particular keeps
/// its own volume through a Handoff, because a phone's volume means nothing in a room with
/// different acoustics.
class PlayerVolume {
  /// Silent, and the loudest the player goes. The range is the protocol's as well as the player's.
  static const double minimum = 0.0;
  static const double maximum = 1.0;

  double _value = maximum;

  /// The volume every player on this installation starts at. Between [minimum] and [maximum].
  double get value => _value;

  /// Remembers [volume] and answers with the value that was actually kept.
  ///
  /// A value outside the range is held to it rather than refused: this is the installation's own
  /// setting, reached from a slider, and there is no viewer to tell about a rounding error.
  double setValue(double volume) {
    _value = normalise(volume);
    return _value;
  }

  /// [volume] held inside the player's range. Anything unusable reads as loudest, which is where a
  /// player that was never told otherwise already is.
  static double normalise(double volume) {
    if (volume.isNaN) {
      return maximum;
    }
    if (volume < minimum) {
      return minimum;
    }
    if (volume > maximum) {
      return maximum;
    }
    return volume;
  }
}

/// One player volume for the whole application, like a volume knob on the device it runs
/// on. It holds no configuration, no credentials and no connection, so there is nothing about it
/// a test or an environment would need to replace.
final Provider<PlayerVolume> playerVolumeProvider =
    Provider<PlayerVolume>((Ref ref) => PlayerVolume());
