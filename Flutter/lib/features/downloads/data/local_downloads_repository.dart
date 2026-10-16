import '../../../core/db/daos/downloads_dao.dart';
import '../domain/download_models.dart';

class LocalDownloadsRepository {
  LocalDownloadsRepository(this._dao);

  final DownloadsDao _dao;

  Future<void> save(DownloadItem item) {
    return _dao.upsertDownload(
      videoId: item.videoId,
      status: item.status.value,
      progress: item.progress,
      title: item.title,
      queuedAt: item.queuedAt,
      speedMbps: item.speedMbps,
      etaSeconds: item.eta?.inSeconds,
      taskId: item.taskId,
      localPath: item.localPath,
      remoteUrl: item.remoteUrl,
    );
  }

  Future<void> queueDownload({
    required int videoId,
    required String remoteUrl,
    String? title,
    DateTime? queuedAt,
    String? taskId,
    String? localPath,
  }) {
    return _dao.upsertDownload(
      videoId: videoId,
      status: DownloadStatus.queued.value,
      progress: 0,
      title: title,
      queuedAt: (queuedAt ?? DateTime.now().toUtc()).toUtc(),
      speedMbps: null,
      etaSeconds: null,
      taskId: taskId,
      remoteUrl: remoteUrl,
      localPath: localPath,
    );
  }

  Future<void> delete(int videoId) {
    return _dao.deleteByVideoId(videoId);
  }

  Future<List<DownloadItem>> listAll() async {
    final List<Map<String, Object?>> rows = await _dao.listAll();
    return rows.map(DownloadItem.fromDb).toList(growable: false);
  }

  Future<DownloadItem?> findByVideoId(int videoId) async {
    final Map<String, Object?>? row = await _dao.findByVideoId(videoId);
    if (row == null) {
      return null;
    }
    return DownloadItem.fromDb(row);
  }

  Future<DownloadItem?> findByTaskId(String taskId) async {
    final Map<String, Object?>? row = await _dao.findByTaskId(taskId);
    if (row == null) {
      return null;
    }
    return DownloadItem.fromDb(row);
  }
}
