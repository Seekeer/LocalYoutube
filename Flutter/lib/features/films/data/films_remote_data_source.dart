import 'package:dio/dio.dart';

import '../domain/film_models.dart';

/// Server calls of the website's «Фильмы» page.
class FilmsRemoteDataSource {
  FilmsRemoteDataSource(this._dio);

  /// `VideoType.Film` on the server.
  static const int filmVideoType = 1;

  /// The website marks a film watched by moving its position far past the end.
  static const double watchedPositionSeconds = 100000;

  final Dio _dio;

  Future<List<Film>> loadFilms() async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '/files/getFileByType/$filmVideoType',
        options: Options(extra: <String, dynamic>{'idempotent': true}),
      );
    } on DioException catch (error) {
      // The server answers 404 when the section is empty.
      if (error.response?.statusCode == 404) {
        return const <Film>[];
      }
      rethrow;
    }
    final dynamic payload = response.data;
    if (payload is! List) {
      return const <Film>[];
    }
    return payload
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> row) => Film.fromJson(
            row.map((dynamic key, dynamic value) => MapEntry('$key', value)),
          ),
        )
        .where((Film film) => film.id > 0)
        .toList(growable: false);
  }

  Future<void> markWatched(int videoId) async {
    await _dio.put<dynamic>(
      '/files/setPosition/$videoId',
      data: watchedPositionSeconds,
      options: Options(
        contentType: Headers.jsonContentType,
        extra: <String, dynamic>{'idempotent': true},
      ),
    );
  }
}
