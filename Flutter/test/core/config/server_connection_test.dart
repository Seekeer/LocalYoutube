import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/config/server_connection.dart';
import 'package:localtube_flutter/core/storage/secure_storage_service.dart';

class MemoryStorage extends SecureStorageService {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  test('JSON and QR share a round-trippable, normalized connection document',
      () {
    final input = ServerConnection(
        apiBaseUrl: ' https://API.example:9999/ ',
        localApiHost: '192.0.2.10',
        localApiPort: 55);
    final decoded = ServerConnection.parse(input.encode());
    expect(decoded.apiBaseUrl, 'https://api.example:9999');
    expect(decoded.localApiHost, '192.0.2.10');
    expect(decoded.localApiPort, 55);
    final config = decoded.applyTo(const AppConfig(
        apiBaseUrl: 'https://old.example',
        connectTimeoutMs: 10,
        receiveTimeoutMs: 20,
        sendTimeoutMs: 30,
        crashReportUrl: 'https://old.example/crash'));
    expect(config.crashReportUrl, isEmpty);
    expect(config.enableLocalApiRoute, isTrue);
    expect(config.connectTimeoutMs, 10);
  });
  for (final address in [
    'ftp://example.com',
    Uri(scheme: 'https', host: 'example.com', userInfo: 'user:password')
        .toString(),
    'https://example.com/api',
    'https://example.com?token=a',
    'https://example.com#fragment',
    '',
    'https://example.com:70000'
  ]) {
    test('rejects invalid API address $address', () {
      expect(
          () => ServerConnection(apiBaseUrl: address), throwsFormatException);
    });
  }
  test('rejects version mismatch, credential fields and invalid LAN settings',
      () {
    for (final input in [
      '{"kind":"localtube-server","version":2,"apiBaseUrl":"https://example.com"}',
      '{"kind":"localtube-server","version":1,"apiBaseUrl":"https://example.com","accessToken":"secret"}',
      '{"kind":"localtube-server","version":1,"apiBaseUrl":"https://example.com","localApiPort":"55"}'
    ]) {
      expect(() => ServerConnection.parse(input), throwsFormatException);
    }
    expect(
        () => ServerConnection(
            apiBaseUrl: 'https://example.com',
            localApiHost: 'https://lan',
            localApiPort: 55),
        throwsFormatException);
    expect(
        () => ServerConnection(
            apiBaseUrl: 'https://example.com', localApiPort: 55),
        throwsFormatException);
  });
  test(
      'changing API clears saved credentials before persisting; same API retains session',
      () async {
    final storage = MemoryStorage();
    final store = ServerConnectionStore(storage);
    await store.save(ServerConnection(apiBaseUrl: 'https://one.example'));
    storage.values.addAll({
      'access_token': 'old',
      'refresh_token': 'refresh',
      'saved_password': 'password'
    });
    await store.save(ServerConnection(apiBaseUrl: 'https://one.example/'));
    expect(storage.values['access_token'], 'old');
    final second = ServerConnection(apiBaseUrl: 'https://two.example');
    await store.save(second);
    expect(storage.values.containsKey('access_token'), isFalse);
    expect(storage.values.containsKey('saved_password'), isFalse);
    expect((await store.load())!.apiBaseUrl, second.apiBaseUrl);
    expect(
        second.databaseName,
        isNot(
            ServerConnection(apiBaseUrl: 'https://one.example').databaseName));
  });
  test(
      'corrupt stored config opens setup rather than trusting an invalid endpoint',
      () async {
    final storage = MemoryStorage();
    storage.values[ServerConnectionStore.key] = 'not json';
    expect(await ServerConnectionStore(storage).load(), isNull);
  });
}
