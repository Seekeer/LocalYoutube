import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/downloads/domain/download_models.dart';

void main() {
  test('download status value roundtrip', () {
    for (final DownloadStatus status in DownloadStatus.values) {
      expect(DownloadStatusX.fromValue(status.value), status);
    }
    expect(DownloadStatusX.fromValue('unknown'), DownloadStatus.failed);
  });

  test('download item parses from db map', () {
    final DownloadItem item = DownloadItem.fromDb(<String, Object?>{
      'video_id': 42,
      'status': 'downloading',
      'progress': 0.4,
      'task_id': 'task-42',
      'local_path': 'C:/tmp/video_42.bin',
      'remote_url': '/files/getFileById?fileId=42',
      'updated_at': '2026-02-15T10:00:00Z',
    });

    expect(item.videoId, 42);
    expect(item.status, DownloadStatus.downloading);
    expect(item.progress, 0.4);
    expect(item.taskId, 'task-42');
    expect(item.localPath, 'C:/tmp/video_42.bin');
    expect(item.remoteUrl, '/files/getFileById?fileId=42');
    expect(
        item.updatedAt.toUtc().toIso8601String(), '2026-02-15T10:00:00.000Z');
  });
}
