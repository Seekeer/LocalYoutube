import '../../../../core/errors/failure.dart';
import '../../data/auth_repository.dart';

class LogoutUseCase {
  LogoutUseCase(this._authRepository);

  final AuthRepository _authRepository;

  Future<Failure?> call() {
    return _authRepository.logout();
  }
}
