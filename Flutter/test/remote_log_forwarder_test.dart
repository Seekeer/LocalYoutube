import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/auth/session_tokens.dart';
import 'package:localtube_flutter/core/auth/token_repository.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/core/logging/remote_log_forwarder.dart';
import 'package:mocktail/mocktail.dart';

class _Tokens extends Mock implements TokenRepository {}

class _Dio extends Mock implements Dio {}

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  test('waits for login, bounds batches and sends sanitized events only',
      () async {
    final tokens = _Tokens();
    final client = _Dio();
    final logs = LogService();
    when(() => tokens.read()).thenAnswer((_) async => null);
    Map<String, dynamic>? body;
    Options? options;
    when(() => client.post<Object?>(any(),
        data: any(named: 'data'),
        options: any(named: 'options'))).thenAnswer((invocation) async {
      body = invocation.namedArguments[#data] as Map<String, dynamic>;
      options = invocation.namedArguments[#options] as Options;
      return Response<Object?>(
          requestOptions: RequestOptions(), statusCode: 204);
    });
    final forwarder = RemoteLogForwarder(
        logService: logs,
        tokens: tokens,
        apiBaseUrl: 'https://example.test/',
        client: client,
        version: 'test');
    addTearDown(forwarder.dispose);
    logs.debug('never upload debug');
    for (var i = 0; i < 110; i++) {
      logs.info('event $i password=private');
    }
    await Future<void>.delayed(Duration.zero);
    await forwarder.flush();
    expect(body, isNull);

    when(() => tokens.read()).thenAnswer((_) async => const SessionTokens(
        userName: 'test', accessToken: 'access', refreshToken: 'refresh'));
    await forwarder.flush();
    expect(body!['source'], 'flutter');
    expect(body!['entries'], hasLength(5));
    expect(body.toString(), isNot(contains('private')));
    expect(body.toString(), isNot(contains('never upload debug')));
    expect(
        (body!['entries'] as List).first['message'], startsWith('event 10 '));
    expect(options!.headers!['Authorization'], 'Bearer access');
  });

  test('transport failures neither create logs nor retry the failed batch',
      () async {
    final tokens = _Tokens();
    final client = _Dio();
    final logs = LogService();
    when(() => tokens.read()).thenAnswer((_) async => const SessionTokens(
        userName: 'test', accessToken: 'access', refreshToken: 'refresh'));
    when(() => client.post<Object?>(any(),
        data: any(named: 'data'),
        options: any(named: 'options'))).thenThrow(StateError('offline'));
    final forwarder = RemoteLogForwarder(
        logService: logs,
        tokens: tokens,
        apiBaseUrl: 'https://example.test',
        client: client);
    addTearDown(forwarder.dispose);
    logs.info('one event');
    await Future<void>.delayed(Duration.zero);
    await forwarder.flush();
    await forwarder.flush();
    verify(() => client.post<Object?>(any(),
        data: any(named: 'data'), options: any(named: 'options'))).called(1);
    expect(logs.entries, hasLength(1));
  });
}
