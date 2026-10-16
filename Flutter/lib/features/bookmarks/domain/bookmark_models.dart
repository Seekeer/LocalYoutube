class BookmarkItem {
  const BookmarkItem({
    required this.id,
    required this.videoId,
    required this.positionSeconds,
    required this.caption,
    required this.updatedAt,
  });

  final int id;
  final int videoId;
  final double positionSeconds;
  final String caption;
  final DateTime updatedAt;

  Duration get position =>
      Duration(milliseconds: (positionSeconds * 1000).round());

  bool get isPendingSync => id <= 0;

  factory BookmarkItem.fromLocalRow(Map<String, Object?> row) {
    return BookmarkItem(
      id: _asInt(row['bookmark_id']),
      videoId: _asInt(row['video_id']),
      positionSeconds: _asDouble(row['position_seconds']),
      caption: (row['caption'] ?? '').toString(),
      updatedAt: _parseDateTime(row['updated_at']),
    );
  }

  factory BookmarkItem.fromRemoteJson(Map<String, dynamic> json) {
    final Object? remoteUpdatedAt =
        json['updatedDate'] ?? json['updatedAt'] ?? json['dateUpdated'];
    return BookmarkItem(
      id: _asInt(json['id']),
      videoId: _asInt(json['dbFileId']),
      positionSeconds: _asDouble(json['position']),
      caption: (json['caption'] ?? '').toString(),
      updatedAt: _parseDateTime(remoteUpdatedAt ?? DateTime.now().toUtc()),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _parseDateTime(Object? value) {
    final DateTime? parsed = DateTime.tryParse((value ?? '').toString());
    return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();
  }
}
