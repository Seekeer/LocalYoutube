import '../../../core/db/daos/playback_positions_dao.dart';

class PlaybackPositionSnapshot {
  const PlaybackPositionSnapshot({
    required this.videoId,
    required this.positionSeconds,
    required this.updatedAt,
  });

  final int videoId;
  final double positionSeconds;
  final DateTime updatedAt;
}

class LocalPlaybackRepository {
  LocalPlaybackRepository(this._dao);

  final PlaybackPositionsDao _dao;

  Future<void> savePosition({
    required int videoId,
    required double positionSeconds,
    DateTime? updatedAt,
  }) {
    return _dao.savePosition(
      videoId: videoId,
      positionSeconds: positionSeconds,
      updatedAt: updatedAt,
    );
  }

  Future<double?> getPosition(int videoId) {
    return _dao.readPosition(videoId);
  }

  Future<PlaybackPositionSnapshot?> getSnapshot(int videoId) async {
    final Map<String, Object?>? row = await _dao.readPositionEntry(videoId);
    if (row == null) {
      return null;
    }
    return PlaybackPositionSnapshot(
      videoId: _asInt(row['video_id']),
      positionSeconds: _asDouble(row['position_seconds']),
      updatedAt: _asDateTime(row['updated_at']),
    );
  }

  Future<List<PlaybackPositionSnapshot>> listRecent({int limit = 50}) async {
    final List<Map<String, Object?>> rows = await _dao.listRecent(limit: limit);
    return rows
        .map(
          (Map<String, Object?> row) => PlaybackPositionSnapshot(
            videoId: _asInt(row['video_id']),
            positionSeconds: _asDouble(row['position_seconds']),
            updatedAt: _asDateTime(row['updated_at']),
          ),
        )
        .where((PlaybackPositionSnapshot item) => item.videoId > 0)
        .toList(growable: false);
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
    final String raw = (value ?? '').toString().trim();
    final DateTime? parsed = DateTime.tryParse(raw);
    return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();
  }
}
