import 'package:dio/dio.dart';

import '../domain/catalog_models.dart';

class CatalogRemoteDataSource {
  CatalogRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> loadSection(CatalogSection section) async {
    switch (section) {
      case CatalogSection.latest:
        return _getList(
          '/files/getLatest',
          query: <String, dynamic>{'count': 30},
        );
      case CatalogSection.fresh:
        return _getList('/files/getNew');
      case CatalogSection.history:
        return _getList(
          '/files/getLatest',
          query: <String, dynamic>{'count': 10},
        );
      case CatalogSection.series:
        return _getSeriesAndSeasons();
      case CatalogSection.playlists:
        final List<PlaylistSummary> playlists = await loadPlaylists();
        return playlists
            .map((PlaylistSummary playlist) => playlist.toJson())
            .toList();
    }
  }

  Future<List<PlaylistSummary>> loadPlaylists() async {
    final List<Map<String, dynamic>> rows = await _getList(
      '/playlists/getAll',
    );
    return rows
        .map(PlaylistSummary.fromJson)
        .where((PlaylistSummary playlist) => playlist.id > 0)
        .toList(growable: false);
  }

  Future<int> createPlaylist(String name) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/playlists/add',
      data: <String, dynamic>{'name': name},
    );
    return _parsePlaylistId(response.data);
  }

  Future<void> deleteServerVideo(int videoId) async {
    await _dio.delete<dynamic>(
      '/files/$videoId',
      options: Options(extra: <String, dynamic>{'idempotent': true}),
    );
  }

  Future<void> addToPlaylist({
    required int fileId,
    required int playlistId,
  }) async {
    await _dio.post<dynamic>(
      '/playlists/addToPlaylist',
      data: <String, dynamic>{'fileId': fileId, 'playlistId': playlistId},
    );
  }

  int _parsePlaylistId(dynamic payload) {
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
          payload['id'] ?? payload['playlistId'] ?? payload['result'];
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
      return _parsePlaylistId(
        payload.map((dynamic key, dynamic value) => MapEntry('$key', value)),
      );
    }
    throw const FormatException('Invalid create playlist response payload');
  }

  Future<List<Map<String, dynamic>>> _getList(
    String path, {
    Map<String, dynamic> query = const <String, dynamic>{},
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      path,
      queryParameters: query,
      options: Options(extra: <String, dynamic>{'idempotent': true}),
    );
    final dynamic payload = response.data;
    if (payload is! List) {
      return <Map<String, dynamic>>[];
    }
    return payload
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> row) =>
              row.map((dynamic key, dynamic value) => MapEntry('$key', value)),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _getSeriesAndSeasons() async {
    final List<Map<String, dynamic>> series = await _getList(
      '/series/getAllByOrigin',
    );
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> seriesItem in series) {
      final String seriesName = (seriesItem['name'] ?? 'Series').toString();
      result.add(seriesItem);

      final Object? seasonsRaw = seriesItem['seasons'];
      if (seasonsRaw is! List) {
        continue;
      }

      for (final Object? seasonObj in seasonsRaw) {
        if (seasonObj is! Map) {
          continue;
        }
        final Map<String, dynamic> seasonMap = seasonObj.map(
          (dynamic key, dynamic value) => MapEntry('$key', value),
        );
        result.add(<String, dynamic>{
          ...seasonMap,
          'name': '$seriesName / ${(seasonMap['name'] ?? 'Season')}',
        });
      }
    }
    return result;
  }
}
