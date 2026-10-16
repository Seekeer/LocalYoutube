class SessionTokens {
  const SessionTokens({
    required this.userName,
    required this.accessToken,
    required this.refreshToken,
  });

  final String userName;
  final String accessToken;
  final String refreshToken;

  bool get isValid => accessToken.isNotEmpty && refreshToken.isNotEmpty;
}
