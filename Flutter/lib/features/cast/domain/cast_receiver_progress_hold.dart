/// Which videos' progress a Receiver keeps out of its own account.
///
/// During a Cast Session the video is watched by the person holding the phone, so its progress and
/// watch history belong to the phone's account. The server keeps them there from what the Receiver
/// reports. The Receiver plays the video through the ordinary player, though, and that player
/// writes progress on the app's ordinary path - to whichever account the Receiver is signed in to,
/// which may well be a different one. So the Receiver holds the cast video back from that path.
///
/// A hold outlives its session on purpose. When a session ends, the Receiver is left paused on the
/// cast video, and the player writes once more when it is closed or replaced - by the next cast,
/// say; that write is still somebody else's viewing. A video is released once the Receiver has
/// moved on from it for good, or somebody in front of it picks the paused video up again with its
/// own remote - from then on it is that room's own viewing, and the Receiver's account keeps it.
/// More than one video can be held at once: the previous cast's, until its player has closed, and
/// the current one's.
abstract interface class CastReceiverProgressHold {
  /// Keeps [videoId]'s progress out of this installation's account until it is released.
  void hold(int videoId);

  /// Gives [videoId]'s progress writing back to this installation's account.
  void release(int videoId);
}

/// One answer for the whole application: the Receiver Controller writes it, and the app's ordinary
/// playback-progress path reads it before it writes anything.
class CastReceiverProgressHoldFlag implements CastReceiverProgressHold {
  final Set<int> _held = <int>{};

  /// The videos whose progress is held back right now.
  Set<int> get heldVideoIds => Set<int>.unmodifiable(_held);

  /// Whether [videoId]'s progress is held back from this installation's account right now.
  bool isHeld(int videoId) => _held.contains(videoId);

  @override
  void hold(int videoId) {
    _held.add(videoId);
  }

  @override
  void release(int videoId) {
    _held.remove(videoId);
  }
}
