import '../../../core/errors/failure.dart';

enum AuthAttemptDisposition {
  successOnline,
  enterOffline,
  failure,
}

class AuthAttemptResult {
  const AuthAttemptResult._({
    required this.disposition,
    this.failure,
  });

  const AuthAttemptResult.successOnline()
      : this._(disposition: AuthAttemptDisposition.successOnline);

  const AuthAttemptResult.enterOffline()
      : this._(disposition: AuthAttemptDisposition.enterOffline);

  const AuthAttemptResult.failure(Failure failure)
      : this._(
          disposition: AuthAttemptDisposition.failure,
          failure: failure,
        );

  final AuthAttemptDisposition disposition;
  final Failure? failure;

  bool get isSuccessOnline =>
      disposition == AuthAttemptDisposition.successOnline;

  bool get shouldEnterOffline =>
      disposition == AuthAttemptDisposition.enterOffline;

  bool get isFailure => disposition == AuthAttemptDisposition.failure;
}
