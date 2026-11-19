import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/downloads/domain/download_models.dart';
import 'package:localtube_flutter/features/downloads/domain/download_queue_estimate.dart';
import 'package:localtube_flutter/features/downloads/presentation/downloads_page.dart';

DownloadItem _item(
  int id,
  DownloadStatus status, {
  double progress = 0,
  double? speed,
  Duration? eta,
}) {
  final DateTime now = DateTime.utc(2026, 11, 20);
  return DownloadItem(
    videoId: id,
    status: status,
    progress: progress,
    remoteUrl: '/api/files/getFileById?fileId=$id',
    queuedAt: now,
    updatedAt: now,
    speedMbps: speed,
    eta: eta,
  );
}

void main() {
  test('nothing running at a known speed gives no estimate', () {
    expect(DownloadQueueEstimate.of(<DownloadItem>[]), isNull);
    expect(
      DownloadQueueEstimate.of(<DownloadItem>[
        _item(1, DownloadStatus.queued),
        _item(2, DownloadStatus.paused, progress: 0.5),
      ]),
      isNull,
    );
  });

  test('speeds add up and the time covers everything left', () {
    // 2 MB/s with 100 MB left, 3 MB/s with 150 MB left: 250 MB at 5 MB/s.
    final DownloadQueueEstimate? estimate =
        DownloadQueueEstimate.of(<DownloadItem>[
      _item(1, DownloadStatus.downloading,
          progress: 0.5, speed: 2, eta: const Duration(seconds: 50)),
      _item(2, DownloadStatus.downloading,
          progress: 0.25, speed: 3, eta: const Duration(seconds: 50)),
    ]);
    expect(estimate!.speedMbps, 5);
    expect(estimate.remaining, const Duration(seconds: 50));
  });

  test('a waiting video counts with the average size, a paused one not', () {
    // Running: 100 MB left at half way, so 200 MB in all; the waiting one is
    // taken as 200 MB too: 300 MB at 2 MB/s.
    final DownloadQueueEstimate? estimate =
        DownloadQueueEstimate.of(<DownloadItem>[
      _item(1, DownloadStatus.downloading,
          progress: 0.5, speed: 2, eta: const Duration(seconds: 50)),
      _item(2, DownloadStatus.queued),
      _item(3, DownloadStatus.paused, progress: 0.1),
    ]);
    expect(estimate!.speedMbps, 2);
    expect(estimate.remaining, const Duration(seconds: 150));
  });

  test('a speed without a time left still counts', () {
    final DownloadQueueEstimate? estimate =
        DownloadQueueEstimate.of(<DownloadItem>[
      _item(1, DownloadStatus.downloading, progress: 0.3, speed: 1.5),
    ]);
    expect(estimate!.speedMbps, 1.5);
    expect(estimate.remaining, isNull);
  });

  test('the queue ends no sooner than its slowest running video', () {
    // 10 MB and 100 MB left at 1 MB/s each: the second needs 100 s on its own.
    final DownloadQueueEstimate? estimate =
        DownloadQueueEstimate.of(<DownloadItem>[
      _item(1, DownloadStatus.downloading,
          progress: 0.9, speed: 1, eta: const Duration(seconds: 10)),
      _item(2, DownloadStatus.downloading,
          progress: 0.5, speed: 1, eta: const Duration(seconds: 100)),
    ]);
    expect(estimate!.remaining, const Duration(seconds: 100));
  });

  test('no size to go by yet: speed only', () {
    final DownloadQueueEstimate? estimate =
        DownloadQueueEstimate.of(<DownloadItem>[
      _item(1, DownloadStatus.downloading,
          progress: 0, speed: 2, eta: const Duration(seconds: 50)),
      _item(2, DownloadStatus.queued),
    ]);
    expect(estimate!.speedMbps, 2);
    expect(estimate.remaining, isNull);
  });

  test('the label gives speed, time left and the clock it ends at', () {
    final DateTime now = DateTime(2026, 11, 20, 14, 10);
    expect(
      queueEstimateLabel(
        const DownloadQueueEstimate(
          speedMbps: 4.2,
          remaining: Duration(minutes: 25),
        ),
        now: now,
      ),
      '4,2 МБ/с · ≈25 мин, к 14:35',
    );
    expect(
      queueEstimateLabel(const DownloadQueueEstimate(speedMbps: 0.5), now: now),
      '500 КБ/с',
    );
    expect(
      queueEstimateLabel(
        const DownloadQueueEstimate(speedMbps: 1, remaining: Duration(hours: 30)),
        now: now,
      ),
      '1,0 МБ/с · ≈30 ч',
    );
  });
}
