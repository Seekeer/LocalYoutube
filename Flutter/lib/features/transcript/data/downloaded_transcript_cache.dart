import '../../downloads/domain/download_models.dart';
import '../../downloads/domain/download_service.dart';
import 'transcript_repository.dart';

/// Uses the existing app sync loop; no additional background timer or ASR request.
class DownloadedTranscriptCache {
  DownloadedTranscriptCache(this._downloads, this._transcripts);
  final DownloadService _downloads;
  final TranscriptRepository _transcripts;
  DateTime? _lastAttempt;
  int _cursor = 0;

  Future<void> sync() async {
    final DateTime now = DateTime.now();
    if (_lastAttempt != null &&
        now.difference(_lastAttempt!) < const Duration(minutes: 1)) {
      return;
    }
    _lastAttempt = now;
    final items = (await _downloads.watchDownloads().first)
        .where((item) => item.status == DownloadStatus.completed)
        .toList();
    if (items.isEmpty) return;
    // Bound each pass so transcript caching never monopolizes bookmark synchronization.
    for (int count = 0; count < items.length && count < 3; count++) {
      final item = items[_cursor++ % items.length];
      try {
        if (await _transcripts.cached(item.videoId) != null) continue;
        final status = await _transcripts.status(item.videoId);
        if (status['status'] != 'ready') continue;
        await _transcripts.load(item.videoId);
        await _transcripts.srt(item.videoId);
      } catch (_) {
        break;
      }
    }
  }
}
