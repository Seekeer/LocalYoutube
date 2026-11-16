import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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
///
/// It has a [level] and can be [isMuted] on top of it, like the volume knob and mute button of a
/// desktop player: muting keeps the level, so unmuting brings back exactly what was there. Both are
/// kept by a [PlayerVolumeStore], so the next launch sounds like the last one. Listeners hear about
/// every change, which is how an open player follows the slider.
class PlayerVolume extends ChangeNotifier {
  PlayerVolume({
    PlayerVolumeStore? store,
    double level = maximum,
    bool isMuted = false,
  })  : _store = store,
        _level = normalise(level),
        _isMuted = isMuted;

  /// Silent, and the loudest the player goes. The range is the protocol's as well as the player's.
  static const double minimum = 0.0;
  static const double maximum = 1.0;

  /// Where unmuting a player whose level was dragged all the way down goes back to, so the mute
  /// button never turns the sound "on" to silence.
  static const double unmuteLevel = 0.5;

  /// Reads the volume [store] kept. Anything it cannot read starts at the defaults: a volume is not
  /// worth failing a launch for.
  static Future<PlayerVolume> load(PlayerVolumeStore store) async {
    PlayerVolumeSetting? setting;
    try {
      setting = await store.read();
    } catch (_) {
      setting = null;
    }
    return PlayerVolume(
      store: store,
      level: setting?.level ?? maximum,
      isMuted: setting?.isMuted ?? false,
    );
  }

  final PlayerVolumeStore? _store;
  double _level;
  bool _isMuted;

  /// The writes still to be done, in order: only the newest matters, and none overlaps another.
  Future<void> _pendingWrite = Future<void>.value();
  PlayerVolumeSetting? _queued;

  /// The level the slider shows, kept while muted. Between [minimum] and [maximum].
  double get level => _level;

  /// Whether the player is silent with its [level] kept.
  bool get isMuted => _isMuted;

  /// The volume every player on this installation plays at: silent while muted, otherwise [level].
  double get value => _isMuted ? minimum : _level;

  /// Whether nothing can be heard, muted or turned all the way down.
  bool get isSilent => value <= minimum;

  /// Sets the level to [volume] and unmutes, and answers with the value that was actually kept.
  ///
  /// A value outside the range is held to it rather than refused: this is the installation's own
  /// setting, reached from a slider, and there is no viewer to tell about a rounding error. Moving
  /// the volume is asking to hear it, so it also takes the mute off.
  double setValue(double volume) {
    final double next = normalise(volume);
    if (next != _level || _isMuted) {
      _level = next;
      _isMuted = false;
      _changed();
    }
    return value;
  }

  /// Mutes or unmutes, keeping the [level]. Unmuting a level that sits at silence brings it up to
  /// [unmuteLevel], so the button always does something audible.
  void setMuted(bool muted) {
    if (!muted && _level <= minimum) {
      _level = unmuteLevel;
      _isMuted = false;
      _changed();
      return;
    }
    if (muted == _isMuted) {
      return;
    }
    _isMuted = muted;
    _changed();
  }

  /// What the mute button does: silences a sound that is heard, and brings back a silent one.
  void toggleMuted() => setMuted(!isSilent);

  /// Waits for every write asked for so far. For tests and for closing the app tidily.
  Future<void> flush() => _pendingWrite;

  void _changed() {
    notifyListeners();
    _persist();
  }

  void _persist() {
    final PlayerVolumeStore? store = _store;
    if (store == null) {
      return;
    }
    final bool alreadyQueued = _queued != null;
    _queued = PlayerVolumeSetting(level: _level, isMuted: _isMuted);
    if (alreadyQueued) {
      return;
    }
    _pendingWrite = _pendingWrite.then((_) async {
      final PlayerVolumeSetting? setting = _queued;
      _queued = null;
      if (setting == null) {
        return;
      }
      try {
        await store.write(setting);
      } catch (_) {
        // The volume still works for this run; it is only not remembered.
      }
    });
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

/// The player volume as it is remembered between launches.
@immutable
class PlayerVolumeSetting {
  const PlayerVolumeSetting({required this.level, required this.isMuted});

  final double level;
  final bool isMuted;

  Map<String, Object?> toJson() => <String, Object?>{
        'level': level,
        'muted': isMuted,
      };

  /// The setting in [json], or null when it is not one this app wrote.
  static PlayerVolumeSetting? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final Object? level = json['level'];
    final Object? muted = json['muted'];
    if (level is! num || muted is! bool) {
      return null;
    }
    return PlayerVolumeSetting(
      level: PlayerVolume.normalise(level.toDouble()),
      isMuted: muted,
    );
  }
}

/// Where the installation's player volume is remembered.
abstract class PlayerVolumeStore {
  Future<PlayerVolumeSetting?> read();
  Future<void> write(PlayerVolumeSetting setting);
}

/// Keeps the player volume in a small file in the app's support directory.
///
/// It is not in the database on purpose: the database's session data is cleared at sign-out, and a
/// volume belongs to the device, not to whoever is signed in.
class FilePlayerVolumeStore implements PlayerVolumeStore {
  FilePlayerVolumeStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  static const String fileName = 'player_volume.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final Directory directory = await _directory();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<PlayerVolumeSetting?> read() async {
    final File file = await _file();
    if (!await file.exists()) {
      return null;
    }
    try {
      return PlayerVolumeSetting.fromJson(jsonDecode(await file.readAsString()));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(PlayerVolumeSetting setting) async {
    final File file = await _file();
    await file.parent.create(recursive: true);
    // Written aside and moved over, so a crash mid-write never leaves a half file to read.
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(setting.toJson()), flush: true);
    await temporary.rename(file.path);
  }
}

/// One player volume for the whole application, like a volume knob on the device it runs
/// on. The app loads the remembered one at start and overrides this; without that (in tests, say)
/// it is a volume that is not remembered.
final Provider<PlayerVolume> playerVolumeProvider = Provider<PlayerVolume>((Ref ref) {
  final PlayerVolume volume = PlayerVolume();
  ref.onDispose(volume.dispose);
  return volume;
});
