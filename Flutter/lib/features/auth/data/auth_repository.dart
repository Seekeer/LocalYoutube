import '../../../app/router/auth_notifier.dart';
import '../../../core/auth/token_repository.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/logging/log_service.dart';
import 'auth_attempt_result.dart';
import 'auth_local_session_repository.dart';
import 'auth_remote_data_source.dart';
import 'offline_availability_probe.dart';

class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalSessionRepository localSessionRepository,
    required OfflineAvailabilityProbe offlineAvailabilityProbe,
    required TokenRepository tokenRepository,
    required AuthNotifier authNotifier,
    required LogService logService,
  })  : _remoteDataSource = remoteDataSource,
        _localSessionRepository = localSessionRepository,
        _offlineAvailabilityProbe = offlineAvailabilityProbe,
        _tokenRepository = tokenRepository,
        _authNotifier = authNotifier,
        _logService = logService;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalSessionRepository _localSessionRepository;
  final OfflineAvailabilityProbe _offlineAvailabilityProbe;
  final TokenRepository _tokenRepository;
  final AuthNotifier _authNotifier;
  final LogService _logService;

  Future<AuthAttemptResult> login({
    required String userName,
    required String password,
  }) async {
    try {
      final session = await _remoteDataSource.login(
        userName: userName,
        password: password,
      );
      if (session == null || !session.isValid) {
        _authNotifier.enterSignedOut(
          reason: AuthTransitionReason.loginInvalidCredentials,
        );
        return const AuthAttemptResult.failure(
          AuthFailure('Invalid credentials'),
        );
      }

      await _tokenRepository.save(session);
      await _localSessionRepository.saveSessionMeta(userName: session.userName);
      _authNotifier.enterOnlineAuthenticated(
        reason: AuthTransitionReason.loginSucceeded,
      );
      return const AuthAttemptResult.successOnline();
    } catch (error, stackTrace) {
      _logService.error('Login failed', error, stackTrace);
      return _resolveFailureResult(
        mapToFailure(error),
        allowOfflineFallback: true,
      );
    }
  }

  Future<AuthAttemptResult> refreshSession({
    bool allowOfflineFallback = false,
  }) async {
    try {
      final session = await _tokenRepository.read();
      if (session == null || !session.isValid) {
        return await _handleFailureResult(const AuthFailure('No session'));
      }

      final refreshed = await _remoteDataSource.refresh(
        userName: session.userName,
        refreshToken: session.refreshToken,
        accessToken: session.accessToken,
      );

      if (refreshed == null || !refreshed.isValid) {
        return await _resolveFailureResult(
          const UnknownFailure('Session refresh response was invalid'),
          allowOfflineFallback: allowOfflineFallback,
          hasValidatedLocalSession: true,
          preferOfflineFallback: true,
        );
      }

      await _tokenRepository.save(refreshed);
      await _localSessionRepository.saveSessionMeta(
          userName: refreshed.userName);
      _authNotifier.enterOnlineAuthenticated(
        reason: AuthTransitionReason.refreshSucceeded,
      );
      return const AuthAttemptResult.successOnline();
    } catch (error, stackTrace) {
      _logService.error('Session refresh failed', error, stackTrace);
      return _resolveFailureResult(
        mapToFailure(error),
        allowOfflineFallback: allowOfflineFallback,
        hasValidatedLocalSession: true,
      );
    }
  }

  Future<AuthAttemptResult> tryAutoLogin() async {
    final AuthAttemptResult refreshedResult = await refreshSession(
      allowOfflineFallback: true,
    );
    if (!refreshedResult.isFailure) {
      return refreshedResult;
    }

    final Failure refreshedFailure = refreshedResult.failure!;
    if (refreshedFailure is AuthFailure ||
        refreshedFailure is ValidationFailure) {
      return refreshedResult;
    }

    try {
      await _tokenRepository.hasAccessToken();
    } catch (error, stackTrace) {
      _logService.error(
        'Auto-login token probe failed; preserving local auth state',
        error,
        stackTrace,
      );
    }
    return refreshedResult;
  }

  Future<Failure?> logout() async {
    try {
      final session = await _tokenRepository.read();
      if (session != null && session.accessToken.isNotEmpty) {
        try {
          await _remoteDataSource.logout(accessToken: session.accessToken);
        } catch (_) {
          // Logout should still clear local sensitive state even if server call fails.
        }
      }

      await _tokenRepository.clearAllAuthState();
      await _localSessionRepository.clearSessionMeta();
      _authNotifier.enterSignedOut(
        reason: AuthTransitionReason.explicitLogout,
      );
      return null;
    } catch (error, stackTrace) {
      _logService.error('Logout failed', error, stackTrace);
      return mapToFailure(error);
    }
  }

  Future<void> logoutOfflineFallback() async {
    await _tokenRepository.clearAllAuthState();
    await _localSessionRepository.clearSessionMeta();
    _authNotifier.enterSignedOut(reason: AuthTransitionReason.explicitLogout);
  }

  Future<bool> enterOfflineFallbackIfAvailable({String? notice}) async {
    if (_authNotifier.isOfflineFallback) {
      return true;
    }
    if (!_authNotifier.isOnlineAuthenticated) {
      return false;
    }

    final bool canEnterOffline =
        await _offlineAvailabilityProbe.canEnterOfflineFallback();
    if (!canEnterOffline) {
      return false;
    }

    _authNotifier.enterOfflineFallback(
      notice: notice ??
          'Network unavailable. Entered offline mode with local data.',
    );
    return true;
  }

  Future<bool> recoverOnlineSession() async {
    if (!_authNotifier.isOfflineFallback) {
      return _authNotifier.isOnlineAuthenticated;
    }

    final AuthAttemptResult result = await refreshSession(
      allowOfflineFallback: false,
    );
    return result.isSuccessOnline;
  }

  Future<AuthAttemptResult> _resolveFailureResult(
    Failure failure, {
    bool allowOfflineFallback = false,
    bool hasValidatedLocalSession = false,
    bool preferOfflineFallback = false,
  }) async {
    final bool shouldPreserveValidatedSession = hasValidatedLocalSession;
    final bool isAuthoritativeRejection =
        _shouldClearSessionForFailure(failure);
    final bool canFallbackFromFailure = !isAuthoritativeRejection &&
        (preferOfflineFallback || _shouldEnterOfflineFallback(failure));
    if (allowOfflineFallback && canFallbackFromFailure) {
      final bool canEnterOffline = hasValidatedLocalSession ||
          await _offlineAvailabilityProbe.canEnterOfflineFallback();
      if (canEnterOffline) {
        _authNotifier.enterOfflineFallback(
          notice: _offlineFallbackNoticeForFailure(failure),
          reason: AuthTransitionReason.refreshNetworkFailurePreserved,
        );
        return const AuthAttemptResult.enterOffline();
      }
    }

    if (isAuthoritativeRejection) {
      await _tokenRepository.clearSession();
      _authNotifier.enterSignedOut(
        reason: AuthTransitionReason.refreshInvalidSession,
      );
    } else if (shouldPreserveValidatedSession) {
      _authNotifier.setAccessMode(
        _authNotifier.accessMode,
        notice: _offlineFallbackNoticeForFailure(failure),
        reason: AuthTransitionReason.refreshNetworkFailurePreserved,
      );
    }
    return AuthAttemptResult.failure(failure);
  }

  Future<AuthAttemptResult> _handleFailureResult(Failure failure) async {
    if (_shouldClearSessionForFailure(failure)) {
      await _tokenRepository.clearSession();
      _authNotifier.enterSignedOut(
        reason: AuthTransitionReason.refreshInvalidSession,
      );
    }
    return AuthAttemptResult.failure(failure);
  }

  bool _shouldClearSessionForFailure(Failure failure) {
    return failure is AuthFailure || failure is ValidationFailure;
  }

  bool _shouldEnterOfflineFallback(Failure failure) {
    if (failure is NetworkFailure) {
      return true;
    }
    if (failure is ServerFailure) {
      return (failure.statusCode ?? 0) >= 500;
    }
    if (failure is UnknownFailure) {
      return true;
    }
    return false;
  }

  String _offlineFallbackNoticeForFailure(Failure failure) {
    if (failure is NetworkFailure) {
      return 'Network unavailable. Entered offline mode with local data.';
    }
    return 'Server unavailable. Staying signed in with local data.';
  }
}
