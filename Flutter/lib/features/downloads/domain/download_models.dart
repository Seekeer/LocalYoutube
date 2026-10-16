enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  damaged,
  failed,
}

extension DownloadStatusX on DownloadStatus {
  String get value {
    switch (this) {
      case DownloadStatus.queued:
        return 'queued';
      case DownloadStatus.downloading:
        return 'downloading';
      case DownloadStatus.paused:
        return 'paused';
      case DownloadStatus.completed:
        return 'completed';
      case DownloadStatus.damaged:
        return 'damaged';
      case DownloadStatus.failed:
        return 'failed';
    }
  }

  bool get isActive =>
      this == DownloadStatus.queued || this == DownloadStatus.downloading;

  static DownloadStatus fromValue(String? value) {
    switch (value) {
      case 'queued':
        return DownloadStatus.queued;
      case 'downloading':
        return DownloadStatus.downloading;
      case 'paused':
        return DownloadStatus.paused;
      case 'completed':
        return DownloadStatus.completed;
      case 'damaged':
        return DownloadStatus.damaged;
      case 'failed':
      default:
        return DownloadStatus.failed;
    }
  }
}

class DownloadItem {
  const DownloadItem({
    required this.videoId,
    required this.status,
    required this.progress,
    required this.remoteUrl,
    required this.queuedAt,
    required this.updatedAt,
    this.title,
    this.speedMbps,
    this.eta,
    this.localPath,
    this.taskId,
  });

  final int videoId;
  final DownloadStatus status;
  final double progress;
  final String remoteUrl;
  final String? title;
  final double? speedMbps;
  final Duration? eta;
  final String? localPath;
  final String? taskId;
  final DateTime queuedAt;
  final DateTime updatedAt;

  DownloadItem copyWith({
    DownloadStatus? status,
    double? progress,
    String? remoteUrl,
    String? title,
    double? speedMbps,
    Duration? eta,
    String? localPath,
    String? taskId,
    DateTime? queuedAt,
    DateTime? updatedAt,
    bool clearTitle = false,
    bool clearSpeedMbps = false,
    bool clearEta = false,
    bool clearLocalPath = false,
    bool clearTaskId = false,
  }) {
    return DownloadItem(
      videoId: videoId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      title: clearTitle ? null : title ?? this.title,
      speedMbps: clearSpeedMbps ? null : speedMbps ?? this.speedMbps,
      eta: clearEta ? null : eta ?? this.eta,
      localPath: clearLocalPath ? null : localPath ?? this.localPath,
      taskId: clearTaskId ? null : taskId ?? this.taskId,
      queuedAt: queuedAt ?? this.queuedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DownloadItem.fromDb(Map<String, Object?> map) {
    final int videoId = (map['video_id'] as num?)?.toInt() ?? 0;
    final double progress = (map['progress'] as num?)?.toDouble() ?? 0;
    final String remoteUrl = (map['remote_url'] ?? '').toString();
    final String statusRaw = (map['status'] ?? '').toString();
    final String titleRaw = (map['title'] ?? '').toString();
    final String localPathRaw = (map['local_path'] ?? '').toString();
    final String taskIdRaw = (map['task_id'] ?? '').toString();
    final String queuedAtRaw = (map['queued_at'] ?? '').toString();
    final double? speedMbps = (map['speed_mbps'] as num?)?.toDouble();
    final int? etaSeconds = (map['eta_seconds'] as num?)?.toInt();
    final String updatedAtRaw = (map['updated_at'] ?? '').toString();
    final DateTime updatedAt =
        DateTime.tryParse(updatedAtRaw)?.toUtc() ?? DateTime.now().toUtc();
    final DateTime queuedAt = DateTime.tryParse(queuedAtRaw)?.toUtc() ??
        DateTime.tryParse(updatedAtRaw)?.toUtc() ??
        updatedAt;

    return DownloadItem(
      videoId: videoId,
      status: DownloadStatusX.fromValue(statusRaw),
      progress: progress.clamp(0, 1).toDouble(),
      remoteUrl: remoteUrl,
      title: titleRaw.trim().isEmpty ? null : titleRaw,
      speedMbps: speedMbps == null || speedMbps < 0 ? null : speedMbps,
      eta: etaSeconds == null || etaSeconds < 0
          ? null
          : Duration(seconds: etaSeconds),
      localPath: localPathRaw.trim().isEmpty ? null : localPathRaw,
      taskId: taskIdRaw.trim().isEmpty ? null : taskIdRaw,
      queuedAt: queuedAt,
      updatedAt: updatedAt,
    );
  }
}
