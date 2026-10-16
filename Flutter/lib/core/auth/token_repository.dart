import '../storage/secure_storage_service.dart';
import 'session_tokens.dart';

abstract interface class TokenRepository {
  Future<SessionTokens?> read();
  Future<void> save(SessionTokens tokens);
  Future<void> clearSession();
  Future<void> clearAllAuthState();
  Future<bool> hasAccessToken();
}

class SecureTokenRepository implements TokenRepository {
  SecureTokenRepository(this._storage);

  static const String _userNameKey = 'user_name';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _savedLoginKey = 'saved_login';
  static const String _savedPasswordKey = 'saved_password';

  final SecureStorageService _storage;

  @override
  Future<void> clearSession() async {
    await _storage.delete(_userNameKey);
    await _storage.delete(_accessTokenKey);
    await _storage.delete(_refreshTokenKey);
  }

  @override
  Future<void> clearAllAuthState() async {
    await clearSession();
    await _storage.delete(_savedLoginKey);
    await _storage.delete(_savedPasswordKey);
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      final String? access = await _storage.read(_accessTokenKey);
      return access != null && access.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SessionTokens?> read() async {
    try {
      final String? userName = await _storage.read(_userNameKey);
      final String? accessToken = await _storage.read(_accessTokenKey);
      final String? refreshToken = await _storage.read(_refreshTokenKey);
      if (userName == null || accessToken == null || refreshToken == null) {
        return null;
      }
      return SessionTokens(
        userName: userName,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(SessionTokens tokens) async {
    await _storage.write(_userNameKey, tokens.userName);
    await _storage.write(_accessTokenKey, tokens.accessToken);
    await _storage.write(_refreshTokenKey, tokens.refreshToken);
  }
}
