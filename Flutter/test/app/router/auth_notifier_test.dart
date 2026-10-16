import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';

void main() {
  test('normalizes refresh network failure preserved reason', () {
    final _RecordingLogService logService = _RecordingLogService();
    final AuthNotifier notifier = AuthNotifier(
      initialMode: AppAccessMode.onlineAuthenticated,
      logService: logService,
    );

    notifier.enterOfflineFallback(
      notice: 'offline',
      reason: AuthTransitionReason.refreshNetworkFailurePreserved,
    );

    expect(
      notifier.lastTransitionReason,
      AuthTransitionReason.refreshNetworkFailurePreserved,
    );
    expect(
      notifier.lastTransitionReasonCode,
      'refresh-network-failure-preserved',
    );
    expect(logService.infoMessages.single, contains('Auth transition:'));
    expect(
      logService.infoMessages.single,
      contains('reason=refresh-network-failure-preserved'),
    );
  });

  test('normalizes bootstrap auto login success reason', () {
    final AuthNotifier notifier = AuthNotifier(
      initialMode: AppAccessMode.checkingSession,
    );

    notifier.enterOnlineAuthenticated(
      reason: AuthTransitionReason.refreshSucceeded,
    );

    expect(
      notifier.lastTransitionReason,
      AuthTransitionReason.bootstrapAutoLoginSuccess,
    );
    expect(notifier.lastTransitionReasonCode, 'bootstrap-auto-login-success');
  });

  test('normalizes bootstrap auth failure while checking session', () {
    final AuthNotifier notifier = AuthNotifier(
      initialMode: AppAccessMode.checkingSession,
    );

    notifier.enterSignedOut(reason: AuthTransitionReason.refreshInvalidSession);

    expect(
      notifier.lastTransitionReason,
      AuthTransitionReason.bootstrapAutoLoginAuthFailed,
    );
    expect(
      notifier.lastTransitionReasonCode,
      'bootstrap-auto-login-auth-failed',
    );
  });

  test('normalizes refresh auth failure reason for sign out transitions', () {
    final AuthNotifier notifier = AuthNotifier(
      initialMode: AppAccessMode.onlineAuthenticated,
    );

    notifier.enterSignedOut(reason: AuthTransitionReason.refreshInvalidSession);

    expect(
      notifier.lastTransitionReason,
      AuthTransitionReason.refreshInvalidSession,
    );
    expect(notifier.lastTransitionReasonCode, 'refresh-invalid-session');
  });

  test('preserves the last transition reason on redundant no-op transitions',
      () {
    final AuthNotifier notifier = AuthNotifier(
      initialMode: AppAccessMode.onlineAuthenticated,
    );

    notifier.enterSignedOut(reason: AuthTransitionReason.explicitLogout);
    notifier.enterSignedOut();

    expect(notifier.lastTransitionReason, AuthTransitionReason.explicitLogout);
    expect(notifier.lastTransitionReasonCode, 'explicit-logout');
  });
}

class _RecordingLogService extends LogService {
  final List<String> infoMessages = <String>[];

  @override
  void info(String message) {
    infoMessages.add(message);
  }

  @override
  void debug(String message) {}

  @override
  void warn(String message) {}

  @override
  void error(String message, Object error, StackTrace stackTrace) {}
}
