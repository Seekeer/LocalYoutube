import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The player screens that are open right now, in the order they were opened.
///
/// Only the video of the screen on top may play. A player whose screen is covered by another
/// player screen, or that has no screen at all, is not what the viewer is watching: it is paused
/// and it may not start, so audio can never come from a video the viewer cannot see.
class PlayerScreenStack extends ChangeNotifier {
  final List<_PlayerScreenEntry> _entries = <_PlayerScreenEntry>[];

  /// The video of the player screen on top, or `null` when no player screen is open.
  int? get topVideoId => _entries.isEmpty ? null : _entries.last.videoId;

  /// Records that a player screen for [videoId] opened. The returned token closes it again.
  Object enter(int videoId) {
    final Object token = Object();
    _entries.add(_PlayerScreenEntry(token, videoId));
    notifyListeners();
    return token;
  }

  /// Records that the player screen opened with [token] closed.
  void leave(Object token) {
    final int before = _entries.length;
    _entries.removeWhere((_PlayerScreenEntry entry) => identical(entry.token, token));
    if (_entries.length != before) {
      notifyListeners();
    }
  }

  /// Whether a player of [videoId] may play: only when its screen is the one on top.
  bool mayPlay(int videoId) => topVideoId == videoId;
}

class _PlayerScreenEntry {
  const _PlayerScreenEntry(this.token, this.videoId);

  final Object token;
  final int videoId;
}

final Provider<PlayerScreenStack> playerScreenStackProvider =
    Provider<PlayerScreenStack>((Ref ref) {
  final PlayerScreenStack stack = PlayerScreenStack();
  ref.onDispose(stack.dispose);
  return stack;
});
