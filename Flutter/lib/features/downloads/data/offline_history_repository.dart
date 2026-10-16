import 'dart:io';

import '../../../core/db/app_database.dart';
import '../../catalog/data/local_video_metadata_repository.dart';
import '../domain/download_models.dart';

class OfflineHistoryItem {
  const OfflineHistoryItem({
    required this.videoId,
    required this.title,
    required this.description,
    required this.lastWatchedAt,
    required this.positionSeconds,
    required this.isPlayableOffline,
    this.durationSeconds,
    this.seasonName,
    this.thumbnailLocalPath,
    this.localVideoPath,
  });

  final int videoId;
  final String title;
  final String description;
  final DateTime lastWatchedAt;
  final double positionSeconds;
  final int? durationSeconds;
  final String? seasonName;
  final String? thumbnailLocalPath;
  final String? localVideoPath;
  final bool isPlayableOffline;
}

class OfflineHistoryRepository {
  OfflineHistoryRepository({
    required AppDatabase database,
    required LocalVideoMetadataRepository localVideoMetadataRepository,
  })  : _database = database,
        _localVideoMetadataRepository = localVideoMetadataRepository;

  final AppDatabase _database;
  final LocalVideoMetadataRepository _localVideoMetadataRepository;

  Future<List<OfflineHistoryItem>> listHistory({int limit = 100}) async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT playback_positions.video_id,
             playback_positions.position_seconds,
             playback_positions.updated_at AS playback_updated_at,
             downloads.status AS download_status,
             downloads.local_path AS local_path,
             video_metadata.title AS metadata_title,
             video_metadata.description AS metadata_description,
             video_metadata.duration_seconds AS duration_seconds,
             video_metadata.season_name AS season_name,
             video_metadata.thumbnail_local_path AS thumbnail_local_path
      FROM playback_positions
      LEFT JOIN video_metadata
        ON video_metadata.video_id = playback_positions.video_id
      LEFT JOIN downloads
        ON downloads.video_id = playback_positions.video_id
      ORDER BY playback_positions.updated_at DESC
      LIMIT ?
      ''',
      variables: <Object?>[limit],
    );

    final List<OfflineHistoryItem> result = <OfflineHistoryItem>[];
    for (final Map<String, Object?> row in rows) {
      result.add(await _toHistoryItem(row));
    }
    return result;
  }

  Future<OfflineHistoryItem?> findLatestPlayable() async {
    final List<OfflineHistoryItem> items = await listHistory(limit: 100);
    for (final OfflineHistoryItem item in items) {
      if (item.isPlayableOffline) {
        return item;
      }
    }
    return null;
  }

  Future<void> ensureMetadataForDownload({
    required int videoId,
    String? title,
  }) async {
    final String normalizedTitle = (title ?? '').trim();
    if (normalizedTitle.isEmpty) {
      return;
    }
    final LocalVideoMetadata? existing =
        await _localVideoMetadataRepository.findByVideoId(videoId);
    if (existing != null && existing.title.trim().isNotEmpty) {
      return;
    }
    await _localVideoMetadataRepository.upsertRouteMetadata(
      videoId: videoId,
      title: normalizedTitle,
    );
  }

  Future<OfflineHistoryItem> _toHistoryItem(Map<String, Object?> row) async {
    final String? localPath = _normalizeNullableString(row['local_path']);
    final String statusRaw = (row['download_status'] ?? '').toString().trim();
    final bool isCompleted =
        DownloadStatusX.fromValue(statusRaw) == DownloadStatus.completed;
    final bool fileExists = localPath != null && await File(localPath).exists();
    final int videoId = _asInt(row['video_id']);
    final String title =
        _normalizeNullableString(row['metadata_title']) ?? 'Video #$videoId';
    final String description =
        _normalizeNullableString(row['metadata_description']) ?? '';

    return OfflineHistoryItem(
      videoId: videoId,
      title: title,
      description: description,
      lastWatchedAt: _asDateTime(row['playback_updated_at']),
      positionSeconds: _asDouble(row['position_seconds']),
      durationSeconds: _nullableInt(row['duration_seconds']),
      seasonName: _normalizeNullableString(row['season_name']),
      thumbnailLocalPath: _normalizeNullableString(row['thumbnail_local_path']),
      localVideoPath: localPath,
      isPlayableOffline: isCompleted && fileExists,
    );
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _nullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString().trim());
  }

  double _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime _asDateTime(Object? value) {
    final DateTime? parsed = DateTime.tryParse((value ?? '').toString().trim());
    return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();
  }

  String? _normalizeNullableString(Object? value) {
    final String normalized = (value ?? '').toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}
