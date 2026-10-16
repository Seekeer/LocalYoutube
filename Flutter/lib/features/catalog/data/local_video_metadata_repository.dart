import '../../../core/db/daos/video_metadata_dao.dart';
import '../domain/catalog_models.dart';

class LocalVideoMetadata {
  const LocalVideoMetadata({
    required this.videoId,
    required this.title,
    required this.description,
    required this.updatedAt,
    this.durationSeconds,
    this.seasonName,
    this.seasonId,
    this.thumbnailLocalPath,
    this.thumbnailUpdatedAt,
  });

  final int videoId;
  final String title;
  final String description;
  final int? durationSeconds;
  final String? seasonName;
  final int? seasonId;
  final String? thumbnailLocalPath;
  final DateTime updatedAt;
  final DateTime? thumbnailUpdatedAt;
}

class LocalVideoMetadataRepository {
  LocalVideoMetadataRepository(this._dao);

  final VideoMetadataDao _dao;

  Future<void> upsertCatalogItem(CatalogItem item) {
    return _dao.upsert(
      videoId: item.id,
      title: item.title,
      description: item.description,
      durationSeconds: _readDurationSeconds(item.raw),
      seasonName: _readSeasonName(item.raw),
      seasonId: _readSeasonId(item.raw),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> upsertCatalogItems(List<CatalogItem> items) async {
    for (final CatalogItem item in items) {
      await upsertCatalogItem(item);
    }
  }

  Future<void> upsertRouteMetadata({
    required int videoId,
    String? title,
    String? description,
  }) {
    return _dao.upsert(
      videoId: videoId,
      title: (title ?? '').trim(),
      description: (description ?? '').trim(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> updateThumbnail({
    required int videoId,
    required String thumbnailLocalPath,
    DateTime? updatedAt,
  }) {
    return _dao.updateThumbnail(
      videoId: videoId,
      thumbnailLocalPath: thumbnailLocalPath,
      updatedAt: updatedAt,
    );
  }

  Future<Map<int, String>> listThumbnailPaths() {
    return _dao.listThumbnailPaths();
  }

  Future<LocalVideoMetadata?> findByVideoId(int videoId) async {
    final Map<String, Object?>? row = await _dao.findByVideoId(videoId);
    if (row == null) {
      return null;
    }
    return LocalVideoMetadata(
      videoId: _asInt(row['video_id']),
      title: (row['title'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      durationSeconds: _nullableInt(row['duration_seconds']),
      seasonName: _normalizeNullableString(row['season_name']),
      seasonId: _nullableInt(row['season_id']),
      thumbnailLocalPath: _normalizeNullableString(row['thumbnail_local_path']),
      thumbnailUpdatedAt: _nullableDateTime(row['thumbnail_updated_at']),
      updatedAt: _asDateTime(row['updated_at']),
    );
  }

  int? _readSeasonId(Map<String, dynamic> raw) {
    return _nullableInt(raw['seasonId'] ?? raw['SeasonId']);
  }

  String? _readSeasonName(Map<String, dynamic> raw) {
    return _normalizeNullableString(
      raw['seasonName'] ?? raw['SeasonName'] ?? raw['season'] ?? raw['Season'],
    );
  }

  int? _readDurationSeconds(Map<String, dynamic> raw) {
    final Object? value = raw['duration'] ??
        raw['Duration'] ??
        raw['durationSeconds'] ??
        raw['DurationSeconds'];
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.round();
    }

    final String rawValue = value.toString().trim();
    if (rawValue.isEmpty) {
      return null;
    }

    final bool isNegative = rawValue.startsWith('-');
    final String normalized = isNegative ? rawValue.substring(1) : rawValue;
    final List<String> parts = normalized.split(':');
    if (parts.length < 2) {
      return int.tryParse(rawValue);
    }

    int days = 0;
    String hoursPart = parts[0];
    if (hoursPart.contains('.')) {
      final List<String> dayAndHours = hoursPart.split('.');
      if (dayAndHours.length == 2) {
        days = int.tryParse(dayAndHours[0]) ?? 0;
        hoursPart = dayAndHours[1];
      }
    }

    final int? hours = int.tryParse(hoursPart);
    final int? minutes = int.tryParse(parts[1]);
    final int? seconds =
        int.tryParse(parts.length > 2 ? parts[2].split('.').first : '0');
    if (hours == null || minutes == null || seconds == null) {
      return null;
    }

    final Duration duration = Duration(
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
    return isNegative ? null : duration.inSeconds;
  }

  int _asInt(Object? value) {
    return _nullableInt(value) ?? 0;
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

  String? _normalizeNullableString(Object? value) {
    final String normalized = (value ?? '').toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  DateTime _asDateTime(Object? value) {
    return _nullableDateTime(value) ??
        DateTime.fromMillisecondsSinceEpoch(0).toUtc();
  }

  DateTime? _nullableDateTime(Object? value) {
    final String raw = (value ?? '').toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }
}
