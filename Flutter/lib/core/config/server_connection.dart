import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../auth/token_repository.dart';
import '../storage/secure_storage_service.dart';
import 'app_config.dart';

/// A connection document contains no account credentials and works as JSON or QR.
class ServerConnection {
  ServerConnection._(this.apiBaseUrl, this.localApiHost, this.localApiPort);
  factory ServerConnection(
      {required String apiBaseUrl,
      String localApiHost = '',
      int localApiPort = 0}) {
    final uri = Uri.tryParse(apiBaseUrl.trim());
    if (uri == null ||
        !const ['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.port < 1 ||
        uri.port > 65535) {
      throw const FormatException(
          'Укажите адрес API: https://server.example:9999');
    }
    final host = localApiHost.trim();
    if (host.isNotEmpty &&
        (!RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(host) ||
            localApiPort < 1 ||
            localApiPort > 65535)) {
      throw const FormatException(
          'Проверьте локальный адрес и порт (1–65535).');
    }
    if (host.isEmpty && localApiPort != 0) {
      throw const FormatException('Для локального порта нужен адрес.');
    }
    return ServerConnection._(
        uri.replace(path: '').toString(), host, localApiPort);
  }
  factory ServerConnection.parse(String text) {
    if (utf8.encode(text).length > 16384) {
      throw const FormatException('Файл конфигурации слишком большой.');
    }
    final Object? value;
    try {
      value = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Некорректный JSON конфигурации.');
    }
    if (value is! Map<String, dynamic> ||
        value['kind'] != 'localtube-server' ||
        value['version'] != 1 ||
        value['apiBaseUrl'] is! String ||
        (value['localApiHost'] != null && value['localApiHost'] is! String) ||
        (value['localApiPort'] != null && value['localApiPort'] is! int)) {
      throw const FormatException(
          'Неподдерживаемый формат конфигурации LocalTube.');
    }
    const allowed = {
      'kind',
      'version',
      'apiBaseUrl',
      'localApiHost',
      'localApiPort'
    };
    if (value.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException(
          'Конфиг должен содержать только параметры подключения.');
    }
    return ServerConnection(
        apiBaseUrl: value['apiBaseUrl'] as String,
        localApiHost: value['localApiHost'] as String? ?? '',
        localApiPort: value['localApiPort'] as int? ?? 0);
  }
  final String apiBaseUrl;
  final String localApiHost;
  final int localApiPort;
  String get storageNamespace =>
      sha256.convert(utf8.encode(apiBaseUrl)).toString();

  String get databaseName =>
      'localtube_${sha256.convert(utf8.encode(apiBaseUrl))}.db';
  String encode() => jsonEncode({
        'kind': 'localtube-server',
        'version': 1,
        'apiBaseUrl': apiBaseUrl,
        'localApiHost': localApiHost,
        'localApiPort': localApiPort
      });
  AppConfig applyTo(AppConfig base) => AppConfig(
      serverStorageNamespace: storageNamespace,
      apiBaseUrl: apiBaseUrl,
      connectTimeoutMs: base.connectTimeoutMs,
      receiveTimeoutMs: base.receiveTimeoutMs,
      sendTimeoutMs: base.sendTimeoutMs,
      crashReportUrl: '',
      environment: base.environment,
      logLevel: base.logLevel,
      enableNetworkLogs: base.enableNetworkLogs,
      enableCrashReporting: base.enableCrashReporting,
      enableLocalApiRoute: localApiHost.isNotEmpty,
      localApiHost: localApiHost,
      localApiPort: localApiPort,
      localApiProbeTimeoutMs: base.localApiProbeTimeoutMs,
      localApiCacheTtlMs: base.localApiCacheTtlMs);
}

class ServerConnectionStore {
  ServerConnectionStore(this.storage);
  final SecureStorageService storage;
  static const key = 'server_connection_v1';
  Future<ServerConnection?> load() async {
    final value = await storage.read(key);
    if (value == null) return null;
    try {
      return ServerConnection.parse(value);
    } on FormatException {
      // Never reuse a session with a fallback server after losing its binding.
      await SecureTokenRepository(storage).clearAllAuthState();
      await storage.delete(key);
      return null;
    }
  }

  Future<void> save(ServerConnection connection,
      {String? previousApiBaseUrl}) async {
    final previous = await load();
    if ((previous?.apiBaseUrl ?? previousApiBaseUrl) != connection.apiBaseUrl) {
      await SecureTokenRepository(storage).clearAllAuthState();
    }
    await storage.write(key, connection.encode());
  }
}
