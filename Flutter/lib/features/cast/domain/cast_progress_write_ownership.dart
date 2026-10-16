/// Which device's playback progress this installation writes.
///
/// Watch history follows the device that is actually playing, and during a Cast Session that device
/// is the Receiver. It plays the cast video through the ordinary player, so its progress already
/// travels the app's ordinary playback-progress path and the server keeps what it sends. Nothing
/// had to be built for that half; this is the other half.
///
/// A phone in Remote Control Mode plays nothing. The only position it has is where the viewer was
/// when the Receiver took over, and writing that carries a fresh timestamp - which is exactly
/// what overwrites the Receiver's real progress with something staler. So it writes nothing at
/// all for as long as the Receiver is the device playing.
///
/// Both halves of that matter equally. A suppression that outlived its Cast Session would go on
/// dropping the viewer's watch history silently, with no session left to explain it, which is worse
/// than the overwrite it exists to prevent. Ownership therefore comes back from the one place the
/// phone leaves a Cast Session, so that every way one can end returns it.
///
/// It is an interface because the Cast Controller has to be driven in a test without the app's
/// persistence, which is a database, a server and an outbox away from anything a Handoff does.
abstract interface class CastProgressWriteOwnership {
  /// Hands playback progress to the Receiver: this installation writes none until [takeBack].
  ///
  /// Called before the local player is given up, because giving it up saves a position.
  ///
  /// Doing it twice is doing it once. A Receiver reports what it is playing over and over, and only
  /// the first of those reports is the moment ownership moved.
  void giveToReceiver();

  /// Takes playback progress back, whatever ended the Cast Session.
  ///
  /// Doing it twice is doing it once, and doing it without having given anything away is doing
  /// nothing: a Handoff that was backed out of never took the local player away, so this device has
  /// been the one playing all along.
  void takeBack();
}

/// One answer for the whole application: the Cast Controller writes it, and the app's ordinary
/// playback-progress path reads it before it writes anything.
///
/// The answer lives here rather than in that path because it is a fact about a Cast Session. All
/// the path has to know is whether this device's progress is still its own to write.
class CastProgressWriteOwnershipFlag implements CastProgressWriteOwnership {
  bool _isReceiverOwned = false;

  /// Whether playback progress is the Receiver's to write right now, so this installation writes
  /// none.
  bool get isReceiverOwned => _isReceiverOwned;

  @override
  void giveToReceiver() {
    _isReceiverOwned = true;
  }

  @override
  void takeBack() {
    _isReceiverOwned = false;
  }
}
