import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/router/auth_notifier.dart';
import '../../../core/errors/failure.dart';
import '../../../core/network/network_status.dart';
import '../../../shared/widgets/lt_widgets.dart';
import '../../../shared/widgets/state_feedback.dart';
import '../data/auth_attempt_result.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, required this.authNotifier});

  final AuthNotifier authNotifier;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const String _savedLoginKey = 'saved_login';
  static const String _savedPasswordKey = 'saved_password';
  static const Duration _loginTimeout = Duration(seconds: 15);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  static const String _loginLabel = 'Имя пользователя';
  static const String _passwordLabel = 'Пароль';
  static const String _submitLabel = 'Войти';

  bool _isBusy = false;
  bool _passwordVisible = false;
  String? _errorMessage;
  int _activeAttemptId = 0;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOffline = _isOfflineNow();
    final TextTheme text = Theme.of(context).textTheme;
    final VoidCallback? serverAction =
        ref.watch(serverConnectionActionProvider);

    return Scaffold(
      appBar: AppBar(
        // The server is changed from the line under the button.
        actions: const <Widget>[],
      ),
      body: SafeArea(
        top: false,
        // Above the middle, so the button stays clear of the keyboard.
        child: Align(
          alignment: const Alignment(0, -0.05),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Center(child: LtLogoMark(size: 64)),
                      const SizedBox(height: 18),
                      Text(
                        'LocalTube',
                        textAlign: TextAlign.center,
                        style: text.headlineMedium?.copyWith(letterSpacing: 0),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Домашняя видеотека. Войдите, чтобы смотреть.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (isOffline)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: StateFeedbackBanner(
                            message: 'Нет сети — для входа нужен интернет.',
                            tone: StateFeedbackTone.warning,
                          ),
                        ),
                      TextFormField(
                        controller: _loginController,
                        decoration: const InputDecoration(
                          labelText: _loginLabel,
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        autocorrect: false,
                        validator: (String? value) {
                          final String text = (value ?? '').trim();
                          if (text.isEmpty) {
                            return 'Введите имя пользователя';
                          }
                          if (text.length < 2) {
                            return 'Слишком короткое имя';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: _passwordLabel,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _passwordVisible
                                ? 'Скрыть пароль'
                                : 'Показать пароль',
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _passwordVisible = !_passwordVisible,
                            ),
                          ),
                        ),
                        obscureText: !_passwordVisible,
                        textInputAction: TextInputAction.done,
                        autofillHints: const <String>[AutofillHints.password],
                        onFieldSubmitted: (_) => _submitLogin(),
                        validator: (String? value) {
                          if ((value ?? '').isEmpty) {
                            return 'Введите пароль';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: StateFeedbackBanner(
                            message: _errorMessage!,
                            tone: StateFeedbackTone.error,
                          ),
                        ),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              (_isBusy || isOffline) ? null : _submitLogin,
                          child: _isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(_submitLabel),
                        ),
                      ),
                      if (_serverHost().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Center(
                          child: serverAction == null
                              ? Text(
                                  'Сервер: ${_serverHost()}',
                                  textAlign: TextAlign.center,
                                  style: text.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        'Сервер: ${_serverHost()}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.bodyMedium?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      key: const Key('login-change-server'),
                                      onPressed: _isBusy ? null : serverAction,
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(48, 48),
                                        textStyle: text.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      child: const Text('Изменить'),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitLogin() async {
    final int attemptId = ++_activeAttemptId;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isOfflineNow()) {
      setState(() {
        _errorMessage = 'Нет подключения к сети';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    AuthAttemptResult result;
    try {
      result = await ref
          .read(loginUseCaseProvider)
          .call(
            userName: _loginController.text.trim(),
            password: _passwordController.text,
          )
          .timeout(_loginTimeout);
    } on TimeoutException {
      result = const AuthAttemptResult.failure(
        AuthAttemptResultFailure.loginTimedOut,
      );
    } catch (_) {
      result = const AuthAttemptResult.failure(
        AuthAttemptResultFailure.loginUnavailable,
      );
    }

    if (!mounted) {
      return;
    }

    if (result.isSuccessOnline || result.shouldEnterOffline) {
      TextInput.finishAutofillContext(shouldSave: true);
      await _persistCredentials(
        userName: _loginController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      context.go(AppRoutes.home);
      return;
    }
    if (_activeAttemptId != attemptId) {
      return;
    }
    final String errorMessage =
        result.failure?.message ?? 'Вход сейчас недоступен';

    setState(() {
      _isBusy = false;
      _errorMessage = errorMessage;
    });
  }

  /// The server this app signs in to, so the person knows which one.
  String _serverHost() {
    try {
      return Uri.parse(ref.read(appConfigProvider).apiBaseUrl).host;
    } catch (_) {
      return '';
    }
  }

  bool _isOfflineNow() {
    return ref.read(networkStatusProvider).maybeWhen(
          data: (NetworkStatus status) => status == NetworkStatus.offline,
          orElse: () => false,
        );
  }

  Future<void> _persistCredentials({
    required String userName,
    required String password,
  }) async {
    final storage = ref.read(secureStorageServiceProvider);
    await storage.write(_savedLoginKey, userName.trim());
    await storage.write(_savedPasswordKey, password);
  }
}

class AuthAttemptResultFailure {
  static const AuthFailure loginTimedOut = AuthFailure(
    'Сервер долго не отвечает. Попробуйте ещё раз.',
  );
  static const AuthFailure loginUnavailable = AuthFailure(
    'Вход временно недоступен. Попробуйте ещё раз.',
  );
}
