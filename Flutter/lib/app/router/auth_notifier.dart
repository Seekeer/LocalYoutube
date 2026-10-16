import 'package:flutter/foundation.dart';

import '../../core/logging/log_service.dart';

enum AppAccessMode {
  checkingSession,
  signedOut,
  onlineAuthenticated,
  offlineFallback,
}

enum AuthTransitionReason {
  bootstrapAutoLoginSuccess,
  bootstrapAutoLoginAuthFailed,
  refreshNetworkFailurePreserved,
  refreshInvalidSession,
  explicitLogout,
  loginInvalidCredentials,
  loginSucceeded,
  refreshSucceeded,
}

extension AuthTransitionReasonCode on AuthTransitionReason {
  String get code {
    switch (this) {
      case AuthTransitionReason.bootstrapAutoLoginSuccess:
        return 'bootstrap-auto-login-success';
      case AuthTransitionReason.bootstrapAutoLoginAuthFailed:
        return 'bootstrap-auto-login-auth-failed';
      case AuthTransitionReason.refreshNetworkFailurePreserved:
        return 'refresh-network-failure-preserved';
      case AuthTransitionReason.refreshInvalidSession:
        return 'refresh-invalid-session';
      case AuthTransitionReason.explicitLogout:
        return 'explicit-logout';
      case AuthTransitionReason.loginInvalidCredentials:
        return 'login-invalid-credentials';
      case AuthTransitionReason.loginSucceeded:
        return 'login-succeeded';
      case AuthTransitionReason.refreshSucceeded:
        return 'refresh-succeeded';
    }
  }
}

class AuthNotifier extends ChangeNotifier {
  AuthNotifier({
    AppAccessMode initialMode = AppAccessMode.checkingSession,
    LogService? logService,
  })  : _accessMode = initialMode,
        _logService = logService;

  AppAccessMode _accessMode;
  String? _pendingAccessNotice;
  AuthTransitionReason? _lastTransitionReason;
  final LogService? _logService;

  AppAccessMode get accessMode => _accessMode;
  AuthTransitionReason? get lastTransitionReason => _lastTransitionReason;
  String? get lastTransitionReasonCode => _lastTransitionReason?.code;

  bool get isCheckingSession => _accessMode == AppAccessMode.checkingSession;

  bool get canEnterAppShell =>
      _accessMode != AppAccessMode.signedOut &&
      _accessMode != AppAccessMode.checkingSession;

  bool get isOnlineAuthenticated =>
      _accessMode == AppAccessMode.onlineAuthenticated;

  bool get isOfflineFallback => _accessMode == AppAccessMode.offlineFallback;

  void setAccessMode(
    AppAccessMode value, {
    String? notice,
    AuthTransitionReason? reason,
  }) {
    final AppAccessMode previousMode = _accessMode;
    final String? previousNotice = _pendingAccessNotice;
    final AuthTransitionReason? normalizedReason = _normalizeTransitionReason(
      reason,
      from: previousMode,
      to: value,
    );
    final bool modeChanged = previousMode != value;
    final bool noticeChanged = notice != null && notice != previousNotice;
    if (!modeChanged && !noticeChanged) {
      if (normalizedReason != null) {
        _lastTransitionReason = normalizedReason;
      }
      return;
    }
    _accessMode = value;
    if (notice != null) {
      _pendingAccessNotice = notice;
    }
    _lastTransitionReason = normalizedReason;
    _logTransition(
      previousMode: previousMode,
      nextMode: value,
      previousNotice: previousNotice,
      nextNotice: _pendingAccessNotice,
      reason: normalizedReason,
      modeChanged: modeChanged,
      noticeChanged: noticeChanged,
    );
    notifyListeners();
  }

  void enterSignedOut({AuthTransitionReason? reason}) =>
      setAccessMode(AppAccessMode.signedOut, reason: reason);

  void enterCheckingSession({AuthTransitionReason? reason}) =>
      setAccessMode(AppAccessMode.checkingSession, reason: reason);

  void enterOnlineAuthenticated({AuthTransitionReason? reason}) =>
      setAccessMode(AppAccessMode.onlineAuthenticated, reason: reason);

  void enterOfflineFallback({
    String? notice,
    AuthTransitionReason? reason,
  }) =>
      setAccessMode(
        AppAccessMode.offlineFallback,
        notice: notice,
        reason: reason,
      );

  String? consumePendingAccessNotice() {
    final String? notice = _pendingAccessNotice;
    _pendingAccessNotice = null;
    return notice;
  }

  AuthTransitionReason? _normalizeTransitionReason(
    AuthTransitionReason? reason, {
    required AppAccessMode from,
    required AppAccessMode to,
  }) {
    if (reason == null) {
      return null;
    }
    switch (reason) {
      case AuthTransitionReason.refreshSucceeded:
        if (from == AppAccessMode.checkingSession &&
            to == AppAccessMode.onlineAuthenticated) {
          return AuthTransitionReason.bootstrapAutoLoginSuccess;
        }
        return reason;
      case AuthTransitionReason.refreshInvalidSession:
        if (from == AppAccessMode.checkingSession &&
            to == AppAccessMode.signedOut) {
          return AuthTransitionReason.bootstrapAutoLoginAuthFailed;
        }
        return reason;
      default:
        return reason;
    }
  }

  void _logTransition({
    required AppAccessMode previousMode,
    required AppAccessMode nextMode,
    required String? previousNotice,
    required String? nextNotice,
    required AuthTransitionReason? reason,
    required bool modeChanged,
    required bool noticeChanged,
  }) {
    _logService?.info(
      'Auth transition: '
      'from=${previousMode.name}, '
      'to=${nextMode.name}, '
      'reason=${reason?.code ?? '-'}, '
      'modeChanged=$modeChanged, '
      'noticeChanged=$noticeChanged, '
      'previousNotice=${_noticeLabel(previousNotice)}, '
      'nextNotice=${_noticeLabel(nextNotice)}.',
    );
  }

  String _noticeLabel(String? notice) {
    final String value = (notice ?? '').trim();
    if (value.isEmpty) {
      return '-';
    }
    return value;
  }
}
