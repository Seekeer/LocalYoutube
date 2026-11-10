import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/errors/failure.dart';
import 'package:localtube_flutter/core/errors/failure_mapper.dart';
import 'package:localtube_flutter/features/catalog/data/catalog_remote_data_source.dart';

void main() {
  test('export posts to the Jellyfin endpoint and returns the server message',
      () async {
    final _JsonAdapter adapter = _JsonAdapter(200, <String, dynamic>{
      'fileId': 42,
      'status': 'Queued',
      'message': 'Видео ещё скачивается',
    });
    final CatalogRemoteDataSource source = CatalogRemoteDataSource(
      Dio(BaseOptions(baseUrl: 'http://api.test/api'))
        ..httpClientAdapter = adapter,
    );

    final String message = await source.exportToJellyfin(42);

    expect(message, 'Видео ещё скачивается');
    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.uri.path, '/api/jellyfin/export/42');
  });

  test('a rejected export surfaces the server explanation', () async {
    final CatalogRemoteDataSource source = CatalogRemoteDataSource(
      Dio(BaseOptions(baseUrl: 'http://api.test/api'))
        ..httpClientAdapter = _JsonAdapter(422, <String, dynamic>{
          'fileId': 7,
          'status': 'Unsupported',
          'message': 'Аудио не экспортируется в Jellyfin.',
        }),
    );

    Object? error;
    try {
      await source.exportToJellyfin(7);
    } catch (caught) {
      error = caught;
    }

    final Failure failure = mapToFailure(error!);
    expect(failure, isA<ValidationFailure>());
    expect(failure.message, 'Аудио не экспортируется в Jellyfin.');
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
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
