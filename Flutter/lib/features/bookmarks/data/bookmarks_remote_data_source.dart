import 'package:dio/dio.dart';

class BookmarksRemoteDataSource {
  BookmarksRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> getAllForVideo(int videoId) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/marks/getAllMarks',
      queryParameters: <String, dynamic>{'fileId': videoId},
      options: Options(extra: <String, dynamic>{'idempotent': true}),
    );

    final dynamic payload = response.data;
    if (payload is! List) {
      return <Map<String, dynamic>>[];
    }

    return payload
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> item) => item.map(
            (dynamic key, dynamic value) => MapEntry('$key', value),
          ),
        )
        .toList(growable: false);
  }

  Future<int> add({
    required int videoId,
    required double positionSeconds,
    required String caption,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/marks/add',
      data: <String, dynamic>{
        'id': 0,
        'dbFileId': videoId,
        'position': positionSeconds,
        'caption': caption,
      },
    );
    return _parseBookmarkId(response.data);
  }

  Future<void> delete(int bookmarkId) async {
    await _dio.delete<dynamic>(
      '/marks/$bookmarkId',
      options: Options(extra: <String, dynamic>{'idempotent': true}),
    );
  }

  int _parseBookmarkId(dynamic payload) {
    if (payload is num) {
      return payload.toInt();
    }
    if (payload is String) {
      final int? parsed = int.tryParse(payload.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    if (payload is Map<String, dynamic>) {
      final dynamic id =
          payload['id'] ?? payload['result'] ?? payload['markId'];
      if (id is num) {
        return id.toInt();
      }
      if (id is String) {
        final int? parsed = int.tryParse(id.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    if (payload is Map<dynamic, dynamic>) {
      return _parseBookmarkId(
        payload.map((dynamic key, dynamic value) => MapEntry('$key', value)),
      );
    }
    throw const FormatException('Invalid add bookmark response payload');
  }
}
