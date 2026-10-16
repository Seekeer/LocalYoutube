import '../../data/auth_attempt_result.dart';
import '../../data/auth_repository.dart';

class LoginUseCase {
  LoginUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Future<AuthAttemptResult> call({
    required String userName,
    required String password,
  }) {
    return _authRepository.login(
      userName: userName,
      password: password,
    );
  }
}
