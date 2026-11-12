import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/films/data/films_remote_data_source.dart';
import 'package:localtube_flutter/features/films/domain/film_models.dart';

void main() {
  test('loads the Film section the website shows', () async {
    final _JsonAdapter adapter = _JsonAdapter(200, <Object?>[
      <String, dynamic>{'id': 5, 'name': 'Солярис', 'year': 1972},
      <String, dynamic>{'id': 0, 'name': 'broken row'},
    ]);
    final FilmsRemoteDataSource source = _source(adapter);

    final List<Film> films = await source.loadFilms();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.uri.path, '/api/files/getFileByType/1');
    expect(films.map((Film f) => f.title), <String>['Солярис']);
  });

  test('an empty section answers 404 and gives no films', () async {
    final FilmsRemoteDataSource source = _source(
      _JsonAdapter(404, 'None file was founded'),
    );

    expect(await source.loadFilms(), isEmpty);
  });

  test('other server errors are reported', () async {
    final FilmsRemoteDataSource source = _source(_JsonAdapter(500, 'boom'));

    expect(source.loadFilms(), throwsA(isA<DioException>()));
  });

  test('marking watched moves the position past the end, as the website does',
      () async {
    final _JsonAdapter adapter = _JsonAdapter(200, null);
    final FilmsRemoteDataSource source = _source(adapter);

    await source.markWatched(42);

    final RequestOptions request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.uri.path, '/api/files/setPosition/42');
    expect(request.contentType, Headers.jsonContentType);
    expect(adapter.bodies.single, '100000.0');
  });
}

FilmsRemoteDataSource _source(_JsonAdapter adapter) {
  return FilmsRemoteDataSource(
    Dio(BaseOptions(baseUrl: 'http://api.test/api'))
      ..httpClientAdapter = adapter,
  );
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.statusCode, this.body);

  final int statusCode;
  final Object? body;
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<String> bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final List<int> bytes = <int>[];
      await for (final Uint8List chunk in requestStream) {
        bytes.addAll(chunk);
      }
      bodies.add(utf8.decode(bytes));
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
