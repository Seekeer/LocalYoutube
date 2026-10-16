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
  testWidgets('app shows launch screen while session check is in progress',
      (WidgetTester tester) async {
    final AuthNotifier authNotifier = AuthNotifier();

    await tester.pumpWidget(
      ProviderScope(
        child: LocalTubeApp(
          router: buildAppRouter(authNotifier: authNotifier),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Login'), findsNothing);
  });

  testWidgets('unauthorized app redirects to login',
      (WidgetTester tester) async {
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.signedOut,
    );
    final _InMemorySecureStorageService storage =
        _InMemorySecureStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          secureStorageServiceProvider.overrideWithValue(storage),
          tryAutoLoginUseCaseProvider
              .overrideWithValue(_AlwaysFailTryAutoLoginUseCase()),
          loginUseCaseProvider.overrideWithValue(_AlwaysFailLoginUseCase()),
          networkStatusProvider.overrideWith(
            (Ref ref) => Stream<NetworkStatus>.value(NetworkStatus.offline),
          ),
        ],
        child: LocalTubeApp(
          router: buildAppRouter(authNotifier: authNotifier),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Login'), findsWidgets);
  });
}

class _InMemorySecureStorageService extends SecureStorageService {
  _InMemorySecureStorageService() : _store = <String, String>{};

  final Map<String, String> _store;

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

class _AlwaysFailTryAutoLoginUseCase implements TryAutoLoginUseCase {
  @override
  Future<AuthAttemptResult> call() async =>
      AuthAttemptResult.failure(const AuthFailure('No session'));
}

class _AlwaysFailLoginUseCase implements LoginUseCase {
  @override
  Future<AuthAttemptResult> call({
    required String userName,
    required String password,
  }) async {
    return AuthAttemptResult.failure(
      const AuthFailure('Login unavailable'),
    );
  }
}
