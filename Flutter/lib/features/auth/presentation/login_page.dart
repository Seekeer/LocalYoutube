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

  bool _isBusy = false;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (isOffline)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: StateFeedbackBanner(
                          message: 'Offline mode: login requires network.',
                          tone: StateFeedbackTone.warning,
                        ),
                      ),
                    TextFormField(
                      controller: _loginController,
                      decoration: const InputDecoration(
                        labelText: 'Login',
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
                          return 'Login is required';
                        }
                        if (text.length < 2) {
                          return 'Login is too short';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.password],
                      onFieldSubmitted: (_) => _submitLogin(),
                      validator: (String? value) {
                        if ((value ?? '').isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StateFeedbackBanner(
                          message: _errorMessage!,
                          tone: StateFeedbackTone.error,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isBusy || isOffline) ? null : _submitLogin,
                        child: _isBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Login'),
                      ),
                    ),
                  ],
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
        _errorMessage = 'No network connection';
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
    final String errorMessage = result.failure?.message ?? 'Login unavailable';

    setState(() {
      _isBusy = false;
      _errorMessage = errorMessage;
    });
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
    'Login request timed out. Please try again.',
  );
  static const AuthFailure loginUnavailable = AuthFailure(
    'Login is temporarily unavailable. Please try again.',
  );
}
