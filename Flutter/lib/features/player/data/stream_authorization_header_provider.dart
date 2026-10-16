import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/auth/session_tokens.dart';
import '../../../core/auth/token_repository.dart';
import '../../../core/logging/log_service.dart';
import '../../../core/network/auth_api.dart';

enum StreamAuthorizationFailureReason {
  missingValidSession,
  invalidRefreshPayload,
  unauthorized,
  refreshFailed,
  missingAccessToken,
  headerReadFailed,
}

extension StreamAuthorizationFailureReasonCode
    on StreamAuthorizationFailureReason {
  String get code {
    switch (this) {
      case StreamAuthorizationFailureReason.missingValidSession:
        return 'missing-valid-session';
      case StreamAuthorizationFailureReason.invalidRefreshPayload:
        return 'invalid-refresh-payload';
      case StreamAuthorizationFailureReason.unauthorized:
        return 'unauthorized';
      case StreamAuthorizationFailureReason.refreshFailed:
        return 'refresh-failed';
      case StreamAuthorizationFailureReason.missingAccessToken:
        return 'missing-access-token';
      case StreamAuthorizationFailureReason.headerReadFailed:
        return 'header-read-failed';
    }
  }
}

class StreamAuthorizationFailure {
  const StreamAuthorizationFailure({
    required this.reason,
    required this.message,
    this.statusCode,
  });

  final StreamAuthorizationFailureReason reason;
  final String message;
  final int? statusCode;

  String get logCode {
    if (reason == StreamAuthorizationFailureReason.unauthorized &&
        statusCode != null) {
      return '${reason.code}-$statusCode';
    }
    return reason.code;
  }
}

class StreamAuthorizationHeaderResult {
  StreamAuthorizationHeaderResult.success(Map<String, String> headers)
      : headers = Map<String, String>.unmodifiable(headers),
        failure = null;

  const StreamAuthorizationHeaderResult.failure(this.failure)
      : headers = const <String, String>{};

  final Map<String, String> headers;
  final StreamAuthorizationFailure? failure;

  bool get isSuccess => failure == null;
  bool get isFailure => !isSuccess;
}

class StreamAuthorizationHeaderProvider {
  StreamAuthorizationHeaderProvider({
    required AuthApi authApi,
    required TokenRepository tokenRepository,
    required LogService logService,
  })  : _authApi = authApi,
        _tokenRepository = tokenRepository,
        _logService = logService;

  final AuthApi _authApi;
  final TokenRepository _tokenRepository;
  final LogService _logService;

  Future<StreamAuthorizationHeaderResult> buildHeaders({
    required bool refreshSession,
    required String reason,
  }) async {
    _PlaybackRefreshOutcome refreshOutcome =
        const _PlaybackRefreshOutcome.notRequested();
    if (refreshSession) {
      refreshOutcome = await _refreshSession(reason: reason);
    }
    _logService.info(
      'Remote stream playback auth ($reason): '
      'refreshStatus=${refreshOutcome.logCode}.',
    );
    if (refreshOutcome.isFailure) {
      final StreamAuthorizationFailure failure = refreshOutcome.failure!;
      _logService.warn(
        'Remote stream auth failure ($reason): '
        'refreshStatus=${refreshOutcome.logCode}, '
        'reason=${failure.logCode}, '
        'message=${_logService.sanitize(failure.message)}.',
      );
      return StreamAuthorizationHeaderResult.failure(failure);
    }

    final StreamAuthorizationHeaderResult result =
        await _readAuthorizationHeaders(
      reason: reason,
      refreshStatus: refreshOutcome.logCode,
    );
    if (result.isSuccess) {
      _logService.info(
        'Remote stream auth success ($reason): '
        'refreshStatus=${refreshOutcome.logCode}.',
      );
    } else {
      final StreamAuthorizationFailure failure = result.failure!;
      _logService.warn(
        'Remote stream auth failure ($reason): '
        'refreshStatus=${refreshOutcome.logCode}, '
        'reason=${failure.logCode}, '
        'message=${_logService.sanitize(failure.message)}.',
      );
    }
    return result;
  }

  Future<_PlaybackRefreshOutcome> _refreshSession({
    required String reason,
  }) async {
    final SessionTokens? session = await _tokenRepository.read();
    if (session == null || !session.isValid) {
      _logService.warn(
        'Skipping playback session refresh ($reason): no valid session.',
      );
      return const _PlaybackRefreshOutcome.failure(
        status: _PlaybackRefreshStatus.missingValidSession,
        failure: StreamAuthorizationFailure(
          reason: StreamAuthorizationFailureReason.missingValidSession,
          message: 'Playback session is unavailable. Please sign in again.',
        ),
      );
    }

    try {
      final SessionTokens? refreshed = await _authApi.refreshToken(
        userName: session.userName,
        refreshToken: session.refreshToken,
        accessToken: session.accessToken,
      );
      if (refreshed == null || !refreshed.isValid) {
        _logService.warn(
          'Playback session refresh returned invalid payload ($reason).',
        );
        return const _PlaybackRefreshOutcome.failure(
          status: _PlaybackRefreshStatus.invalidRefreshPayload,
          failure: StreamAuthorizationFailure(
            reason: StreamAuthorizationFailureReason.invalidRefreshPayload,
            message: 'Playback session refresh returned an invalid response. '
                'Please sign in again.',
          ),
        );
      }
      await _tokenRepository.save(refreshed);
      _logService.info(
        'Playback session refreshed for remote stream ($reason).',
      );
      return const _PlaybackRefreshOutcome.success(
        status: _PlaybackRefreshStatus.refreshed,
      );
    } on DioException catch (error) {
      final int? statusCode = error.response?.statusCode;
      if (statusCode == HttpStatus.unauthorized ||
          statusCode == HttpStatus.forbidden) {
        final String statusLabel = '$statusCode';
        _logService.warn(
          'Playback session refresh rejected for remote stream ($reason): '
          'status=$statusLabel.',
        );
        return _PlaybackRefreshOutcome.failure(
          status: _PlaybackRefreshStatus.unauthorized,
          failure: StreamAuthorizationFailure(
            reason: StreamAuthorizationFailureReason.unauthorized,
            message: 'Playback session expired or was rejected ($statusLabel). '
                'Please sign in again.',
            statusCode: statusCode,
          ),
        );
      }
      _logService.warn(
        'Playback session refresh failed ($reason): '
        '${_logService.sanitize(error.toString())}.',
      );
      return const _PlaybackRefreshOutcome.failure(
        status: _PlaybackRefreshStatus.refreshFailed,
        failure: StreamAuthorizationFailure(
          reason: StreamAuthorizationFailureReason.refreshFailed,
          message: 'Playback session refresh failed. Please try again.',
        ),
      );
    } catch (error, stackTrace) {
      _logService.error(
        'Playback session refresh failed unexpectedly ($reason)',
        error,
        stackTrace,
      );
      return const _PlaybackRefreshOutcome.failure(
        status: _PlaybackRefreshStatus.refreshFailed,
        failure: StreamAuthorizationFailure(
          reason: StreamAuthorizationFailureReason.refreshFailed,
          message: 'Playback session refresh failed. Please try again.',
        ),
      );
    }
  }

  Future<StreamAuthorizationHeaderResult> _readAuthorizationHeaders({
    required String reason,
    required String refreshStatus,
  }) async {
    try {
      final SessionTokens? session = await _tokenRepository.read();
      final String accessToken = (session?.accessToken ?? '').trim();
      if (accessToken.isEmpty) {
        _logService.warn(
          'Remote stream requested without access token ($reason); '
          'refreshStatus=$refreshStatus.',
        );
        return const StreamAuthorizationHeaderResult.failure(
          StreamAuthorizationFailure(
            reason: StreamAuthorizationFailureReason.missingAccessToken,
            message: 'Playback access token is missing. Please sign in again.',
          ),
        );
      }
      _logService.debug(
        'Remote stream authorization header attached from token repository.',
      );
      return StreamAuthorizationHeaderResult.success(<String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $accessToken',
      });
    } catch (error, stackTrace) {
      _logService.error(
        'Failed to build remote stream headers',
        error,
        stackTrace,
      );
      return const StreamAuthorizationHeaderResult.failure(
        StreamAuthorizationFailure(
          reason: StreamAuthorizationFailureReason.headerReadFailed,
          message: 'Unable to read playback authorization. Please try again.',
        ),
      );
    }
  }
}

enum _PlaybackRefreshStatus {
  notRequested,
  refreshed,
  missingValidSession,
  invalidRefreshPayload,
  unauthorized,
  refreshFailed,
}

extension on _PlaybackRefreshStatus {
  String get code {
    switch (this) {
      case _PlaybackRefreshStatus.notRequested:
        return 'not-requested';
      case _PlaybackRefreshStatus.refreshed:
        return 'refreshed';
      case _PlaybackRefreshStatus.missingValidSession:
        return 'missing-valid-session';
      case _PlaybackRefreshStatus.invalidRefreshPayload:
        return 'invalid-refresh-payload';
      case _PlaybackRefreshStatus.unauthorized:
        return 'unauthorized';
      case _PlaybackRefreshStatus.refreshFailed:
        return 'refresh-failed';
    }
  }
}

class _PlaybackRefreshOutcome {
  const _PlaybackRefreshOutcome.success({
    required this.status,
  }) : failure = null;

  const _PlaybackRefreshOutcome.failure({
    required this.status,
    required this.failure,
  });

  const _PlaybackRefreshOutcome.notRequested()
      : status = _PlaybackRefreshStatus.notRequested,
        failure = null;

  final _PlaybackRefreshStatus status;
  final StreamAuthorizationFailure? failure;

  bool get isFailure => failure != null;

  String get logCode {
    final StreamAuthorizationFailure? currentFailure = failure;
    if (currentFailure != null) {
      return currentFailure.logCode;
    }
    return status.code;
  }
}
