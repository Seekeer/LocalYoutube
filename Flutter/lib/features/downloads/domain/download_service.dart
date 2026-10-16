import 'download_models.dart';

abstract interface class DownloadService {
  Future<void> initialize();

  Stream<List<DownloadItem>> watchDownloads();

  Future<void> enqueue({
    required int videoId,
    required String remoteUrl,
    String? title,
  });

  Future<void> pause(int videoId);

  Future<void> resume(int videoId);

  Future<void> stop(int videoId);

  Future<void> deleteLocal(int videoId);
}
