import '../../../core/auth/session_tokens.dart';
import '../../../core/network/auth_api.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._authApi);

  final AuthApi _authApi;

  Future<SessionTokens?> login({
    required String userName,
    required String password,
  }) {
    return _authApi.login(
      userName: userName,
      password: password,
    );
  }

  Future<SessionTokens?> refresh({
    required String userName,
    required String refreshToken,
    required String accessToken,
  }) {
    return _authApi.refreshToken(
      userName: userName,
      refreshToken: refreshToken,
      accessToken: accessToken,
    );
  }

  Future<void> logout({
    required String accessToken,
  }) {
    return _authApi.logout(accessToken: accessToken);
  }
}
