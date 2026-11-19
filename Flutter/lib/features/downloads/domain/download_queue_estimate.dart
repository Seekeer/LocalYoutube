import 'download_models.dart';

/// The whole queue at a glance: how fast it downloads now and roughly how
/// long until everything that is running or waiting is on the phone.
class DownloadQueueEstimate {
  const DownloadQueueEstimate({required this.speedMbps, this.remaining});

  /// Megabytes per second, summed over the downloads running now.
  final double speedMbps;

  /// Time until the last running or waiting video is done; null while no
  /// running download has reported a size to estimate from.
  final Duration? remaining;

  /// Null when nothing is downloading at a known speed.
  static DownloadQueueEstimate? of(Iterable<DownloadItem> items) {
    double speed = 0;
    double remainingMb = 0;
    final List<double> knownSizesMb = <double>[];
    Duration longestRunning = Duration.zero;
    int unknownSize = 0;
    double unknownLeftFraction = 0;

    for (final DownloadItem item in items) {
      if (!item.status.isActive) {
        continue; // Paused, finished and failed videos do not finish by waiting.
      }
      final double progress = item.progress.clamp(0, 1).toDouble();
      final double? itemSpeed = item.speedMbps;
      final Duration? eta = item.eta;
      final bool running = item.status == DownloadStatus.downloading &&
          itemSpeed != null &&
          itemSpeed > 0;
      if (running) {
        speed += itemSpeed;
      }
      if (running && eta != null) {
        if (eta > longestRunning) {
          longestRunning = eta;
        }
        final double leftMb = itemSpeed * eta.inMilliseconds / 1000;
        remainingMb += leftMb;
        if (progress >= 0.02 && progress < 1) {
          knownSizesMb.add(leftMb / (1 - progress));
        }
        continue;
      }
      // Waiting, or running without a reported time left: its size is guessed
      // from the videos whose size is known.
      unknownSize++;
      unknownLeftFraction += 1 - progress;
    }

    if (speed <= 0) {
      return null;
    }
    if (unknownSize > 0) {
      if (knownSizesMb.isEmpty) {
        return DownloadQueueEstimate(speedMbps: speed);
      }
      final double averageMb =
          knownSizesMb.reduce((double a, double b) => a + b) /
              knownSizesMb.length;
      remainingMb += averageMb * unknownLeftFraction;
    }
    if (remainingMb <= 0) {
      return DownloadQueueEstimate(speedMbps: speed);
    }
    final Duration shared = Duration(seconds: (remainingMb / speed).round());
    // Bandwidth freed by a finished download need not go to the others, so
    // the queue never ends before its slowest running video does.
    return DownloadQueueEstimate(
      speedMbps: speed,
      remaining: shared > longestRunning ? shared : longestRunning,
    );
  }
}
