import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'failure.dart';

Failure mapToFailure(Object error) {
  if (error is Failure) {
    return error;
  }

  if (error is DioException) {
    final int? statusCode = error.response?.statusCode;
    final String? responseMessage =
        _extractResponseMessage(error.response?.data);
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const NetworkFailure('Network error');
      case DioExceptionType.cancel:
        return const CancelledFailure('Request cancelled');
      case DioExceptionType.badResponse:
        if (statusCode == 401 || statusCode == 403) {
          return AuthFailure(responseMessage ?? 'Unauthorized');
        }
        if (statusCode == 400 || statusCode == 422) {
          return ValidationFailure(responseMessage ?? 'Validation failed');
        }
        return ServerFailure(
          responseMessage ?? 'Server error',
          statusCode: statusCode,
        );
      case DioExceptionType.unknown:
        final Object? inner = error.error;
        if (inner is SocketException || inner is TimeoutException) {
          return const NetworkFailure('Network error');
        }
        return const UnknownFailure('Unknown network error');
    }
  }

  if (error is SocketException || error is TimeoutException) {
    return const NetworkFailure('Network error');
  }

  return const UnknownFailure('Unknown error');
}

String? _extractResponseMessage(Object? data) {
  if (data == null) {
    return null;
  }

  if (data is String) {
    final String message = data.trim();
    return message.isEmpty ? null : message;
  }

  if (data is Map) {
    final Map<String, dynamic> map = data.map(
      (dynamic key, dynamic value) => MapEntry('$key', value),
    );
    for (final String key in <String>[
      'message',
      'error',
      'title',
      'detail',
    ]) {
      final String value = (map[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
  }

  return null;
}
