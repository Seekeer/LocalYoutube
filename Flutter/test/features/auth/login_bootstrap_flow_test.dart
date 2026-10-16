import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/app.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
import 'package:localtube_flutter/app/router/app_router.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/core/errors/failure.dart';
import 'package:localtube_flutter/core/network/network_status.dart';
import 'package:localtube_flutter/core/storage/secure_storage_service.dart';
import 'package:localtube_flutter/features/auth/data/auth_attempt_result.dart';
import 'package:localtube_flutter/features/auth/domain/usecases/login_use_case.dart';
import 'package:localtube_flutter/features/auth/domain/usecases/try_auto_login_use_case.dart';

void main() {
  testWidgets(
      'login page does not trigger second auto login after bootstrap resolves signed out',
      (WidgetTester tester) async {
    final _CountingTryAutoLoginUseCase tryAutoLoginUseCase =
        _CountingTryAutoLoginUseCase(
      result: const AuthAttemptResult.failure(AuthFailure('No session')),
    );
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.signedOut,
    );

    await tryAutoLoginUseCase.call();

    await tester.pumpWidget(
      _buildApp(
        authNotifier: authNotifier,
        tryAutoLoginUseCase: tryAutoLoginUseCase,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Login'), findsOneWidget);
    expect(tryAutoLoginUseCase.callCount, 1);
  });

  testWidgets(
      'manual login timeout shows explicit message instead of silent hang',
      (WidgetTester tester) async {
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.signedOut,
    );

    await tester.pumpWidget(
      _buildApp(
        authNotifier: authNotifier,
        tryAutoLoginUseCase: _CountingTryAutoLoginUseCase(
          result: const AuthAttemptResult.failure(AuthFailure('No session')),
        ),
        loginUseCase: _TimeoutLoginUseCase(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Login'), 'john');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Login request timed out. Please try again.'),
        findsOneWidget);
  });
}

Widget _buildApp({
  required AuthNotifier authNotifier,
  required TryAutoLoginUseCase tryAutoLoginUseCase,
  LoginUseCase? loginUseCase,
}) {
  return ProviderScope(
    overrides: <Override>[
      secureStorageServiceProvider
          .overrideWithValue(_InMemorySecureStorageService()),
      tryAutoLoginUseCaseProvider.overrideWithValue(tryAutoLoginUseCase),
      loginUseCaseProvider
          .overrideWithValue(loginUseCase ?? _NeverCalledLoginUseCase()),
      networkStatusProvider.overrideWith(
        (Ref ref) => Stream<NetworkStatus>.value(NetworkStatus.online),
      ),
    ],
    child: LocalTubeApp(
      router: buildAppRouter(authNotifier: authNotifier),
    ),
  );
}

class _CountingTryAutoLoginUseCase implements TryAutoLoginUseCase {
  _CountingTryAutoLoginUseCase({required this.result});

  final AuthAttemptResult result;
  int callCount = 0;

  @override
  Future<AuthAttemptResult> call() async {
    callCount += 1;
    return result;
  }
}

class _NeverCalledLoginUseCase implements LoginUseCase {
  @override
  Future<AuthAttemptResult> call({
    required String userName,
    required String password,
  }) {
    return Future<AuthAttemptResult>.error(
      StateError('Manual login should not run in this test.'),
    );
  }
}

class _TimeoutLoginUseCase implements LoginUseCase {
  @override
  Future<AuthAttemptResult> call({
    required String userName,
    required String password,
  }) {
    throw TimeoutException('login timed out');
  }
}

class _InMemorySecureStorageService extends SecureStorageService {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }
}
