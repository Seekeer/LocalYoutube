import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/errors/failure.dart';
import 'package:localtube_flutter/core/errors/failure_mapper.dart';

void main() {
  test('maps socket exception to network failure', () {
    final Failure failure = mapToFailure(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        error: const SocketException('offline'),
        type: DioExceptionType.unknown,
      ),
    );

    expect(failure, isA<NetworkFailure>());
  });

  test('maps 401 to auth failure', () {
    final Failure failure = mapToFailure(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(failure, isA<AuthFailure>());
  });
}
