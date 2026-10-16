import '../../data/auth_attempt_result.dart';
import '../../data/auth_repository.dart';

class RefreshSessionUseCase {
  RefreshSessionUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Future<AuthAttemptResult> call() {
    return _authRepository.refreshSession();
  }
}
