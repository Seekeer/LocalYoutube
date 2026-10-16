import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/player/data/playback_position_remote_data_source.dart';

void main() {
  test('getPosition returns null for 404 response', () async {
    final Dio dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest:
              (RequestOptions options, RequestInterceptorHandler handler) {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 404,
                data: <String, dynamic>{'error': 'not_found'},
              ),
            );
          },
        ),
      );

    final PlaybackPositionRemoteDataSource dataSource =
        PlaybackPositionRemoteDataSource(dio);
    final RemotePlaybackPosition? result = await dataSource.getPosition(65627);
    expect(result, isNull);
  });

  test('getPosition returns null for 204 response', () async {
    final Dio dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest:
              (RequestOptions options, RequestInterceptorHandler handler) {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 204,
                data: null,
              ),
            );
          },
        ),
      );

    final PlaybackPositionRemoteDataSource dataSource =
        PlaybackPositionRemoteDataSource(dio);
    final RemotePlaybackPosition? result = await dataSource.getPosition(65627);
    expect(result, isNull);
  });

  test('getPosition parses payload on 200 response', () async {
    final DateTime updatedAt = DateTime.utc(2026, 3, 1, 12, 0, 0);
    final Dio dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest:
              (RequestOptions options, RequestInterceptorHandler handler) {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'position': 123.45,
                  'updatedDate': updatedAt.toIso8601String(),
                },
              ),
            );
          },
        ),
      );

    final PlaybackPositionRemoteDataSource dataSource =
        PlaybackPositionRemoteDataSource(dio);
    final RemotePlaybackPosition? result = await dataSource.getPosition(65627);
    expect(result, isNotNull);
    expect(result?.positionSeconds, 123.45);
    expect(result?.updatedAt, updatedAt);
  });

  test('getPosition returns null on DioException with 404', () async {
    final Dio dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest:
              (RequestOptions options, RequestInterceptorHandler handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                  data: <String, dynamic>{'error': 'not_found'},
                ),
              ),
            );
          },
        ),
      );

    final PlaybackPositionRemoteDataSource dataSource =
        PlaybackPositionRemoteDataSource(dio);
    final RemotePlaybackPosition? result = await dataSource.getPosition(65627);
    expect(result, isNull);
  });
}
