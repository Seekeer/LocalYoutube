import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/auth/session_tokens.dart';
import 'package:localtube_flutter/core/auth/token_repository.dart';
import 'package:localtube_flutter/core/storage/secure_storage_service.dart';

void main() {
  test('clearSession removes auth tokens but keeps saved credentials',
      () async {
    final InMemorySecureStorageService storage = InMemorySecureStorageService();
    final SecureTokenRepository repository = SecureTokenRepository(storage);

    await repository.save(
      const SessionTokens(
        userName: 'u',
        accessToken: 'a',
        refreshToken: 'r',
      ),
    );
    await storage.write('saved_login', 'u');
    await storage.write('saved_password', 'p');

    await repository.clearSession();

    expect(await storage.read('user_name'), isNull);
    expect(await storage.read('access_token'), isNull);
    expect(await storage.read('refresh_token'), isNull);
    expect(await storage.read('saved_login'), 'u');
    expect(await storage.read('saved_password'), 'p');
  });

  test('clearAllAuthState removes session tokens and saved credentials',
      () async {
    final InMemorySecureStorageService storage = InMemorySecureStorageService();
    final SecureTokenRepository repository = SecureTokenRepository(storage);

    await repository.save(
      const SessionTokens(
        userName: 'u',
        accessToken: 'a',
        refreshToken: 'r',
      ),
    );
    await storage.write('saved_login', 'u');
    await storage.write('saved_password', 'p');

    await repository.clearAllAuthState();

    expect(await storage.read('user_name'), isNull);
    expect(await storage.read('access_token'), isNull);
    expect(await storage.read('refresh_token'), isNull);
    expect(await storage.read('saved_login'), isNull);
    expect(await storage.read('saved_password'), isNull);
  });
}

class InMemorySecureStorageService extends SecureStorageService {
  InMemorySecureStorageService() : _store = <String, String>{};

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
