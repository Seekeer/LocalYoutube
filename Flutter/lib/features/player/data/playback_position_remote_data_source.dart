import 'package:dio/dio.dart';

class RemotePlaybackPosition {
  const RemotePlaybackPosition({
    required this.positionSeconds,
    required this.updatedAt,
  });

  final double positionSeconds;
  final DateTime updatedAt;
}

class PlaybackPositionRemoteDataSource {
  PlaybackPositionRemoteDataSource(this._dio);

  final Dio _dio;

  Future<RemotePlaybackPosition?> getPosition(int videoId) async {
    Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '/files/getPositionMaui/$videoId',
        options: Options(extra: <String, dynamic>{'idempotent': true}),
      );
    } on DioException catch (error) {
      final int? statusCode = error.response?.statusCode;
      if (statusCode == 404 || statusCode == 204) {
        return null;
      }
      rethrow;
    }

    final int? statusCode = response.statusCode;
    if (statusCode == 404 || statusCode == 204) {
      return null;
    }

    final dynamic payload = response.data;
    if (payload is! Map) {
      return null;
    }

    final Map<String, dynamic> map = payload.map(
      (dynamic key, dynamic value) => MapEntry('$key', value),
    );
    final double positionSeconds = _asDouble(map['position']);
    final DateTime updatedAt = _asDateTime(
      map['updatedDate'] ?? map['updatedAt'] ?? map['dateUpdated'],
    );
    return RemotePlaybackPosition(
      positionSeconds: positionSeconds < 0 ? 0 : positionSeconds,
      updatedAt: updatedAt,
    );
  }

  Future<bool> setPosition({
    required int videoId,
    required double positionSeconds,
    required DateTime updatedAt,
  }) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      '/files/setPositionMaui/$videoId',
      data: <String, dynamic>{
        'position': positionSeconds < 0 ? 0 : positionSeconds,
        'updatedDate': updatedAt.toUtc().toIso8601String(),
      },
      options: Options(extra: <String, dynamic>{'idempotent': true}),
    );
    return _asBool(response.data);
  }

  bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final String raw = (value ?? '').toString().trim().toLowerCase();
    if (raw == 'true') {
      return true;
    }
    if (raw == 'false') {
      return false;
    }
    if (value is Map) {
      final Map<String, dynamic> map = value.map(
        (dynamic key, dynamic item) => MapEntry('$key', item),
      );
      return _asBool(map['result'] ?? map['accepted'] ?? map['success']);
    }
    return false;
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
