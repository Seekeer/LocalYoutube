import 'dart:async';

/// The passage of time, as a Cast Session uses it.
///
/// A Receiver reports what it is playing on a cadence, so something has to say when a moment has
/// gone by. Going straight to [Timer] would make that something the machine's own clock, and a test
/// of the cadence would then have to sleep through it - five real seconds for one paused heartbeat,
/// and no way at all to tell "reported because something changed" apart from "reported because the
/// interval elapsed".
///
/// So time arrives through here instead, exactly as it does on the server, where session expiry is
/// driven by an injected `TimeProvider`. The running application supplies [SystemCastClock]; a test
/// supplies a clock it advances itself.
///
/// It is deliberately only what the Cast Session needs: something that happens over and over until
/// it is stopped. There is no "now" here, because nothing in a Cast Session asks what the time is -
/// it asks how long it has been since it last said something, and counting the ticks answers that
/// exactly rather than approximately.
abstract interface class CastClock {
  /// Calls [onTick] every [period] until the returned timer is cancelled.
  CastTimer periodic(Duration period, void Function() onTick);
}

/// Something happening on a cadence, for as long as it is wanted.
abstract interface class CastTimer {
  /// Stops it. Safe to call more than once.
  void cancel();
}

/// The machine's own clock, which is what the running application runs on.
class SystemCastClock implements CastClock {
  const SystemCastClock();

  @override
  CastTimer periodic(Duration period, void Function() onTick) {
    return _SystemCastTimer(Timer.periodic(period, (Timer _) => onTick()));
  }
}

class _SystemCastTimer implements CastTimer {
  _SystemCastTimer(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}
