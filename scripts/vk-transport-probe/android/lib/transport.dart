import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const probePrefix = 'LT-ANDROID-PROBE/1 ';
const mediaUserAgent = 'LocalTubeProbe/1.0 (Android)';
String nonce() => List.generate(16, (_) => Random.secure().nextInt(256))
    .map((n) => n.toRadixString(16).padLeft(2, '0')).join();

class ProbeFailure implements Exception {
  ProbeFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class NativeTransport {
  NativeTransport(this.token, {this.apiBase = 'https://api.vk.ru/method/'});
  final String token;
  final String apiBase;
  final Set<String> hosts = {};
  DateTime _lastApi = DateTime.fromMillisecondsSinceEpoch(0);

  Future<({int status, HttpHeaders headers, Uint8List bytes})> fetch(
      Uri uri, {String? body, Map<String, String> headers = const {},
      int limit = 2 * 1024 * 1024, bool allowLocalTest = false}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      for (var redirects = 0; redirects <= 5; redirects++) {
        if (uri.scheme != 'https' && !(allowLocalTest && uri.host == '127.0.0.1')) {
          throw ProbeFailure('Отклонён адрес без HTTPS');
        }
        if (uri.userInfo.isNotEmpty) throw ProbeFailure('Отклонён адрес с учётными данными');
        hosts.add(uri.host);
        final request = await client.openUrl(body == null ? 'GET' : 'POST', uri)
            .timeout(const Duration(seconds: 15));
        request.followRedirects = false;
        headers.forEach(request.headers.set);
        request.headers.set(HttpHeaders.userAgentHeader, mediaUserAgent);
        if (body != null) {
          request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
          request.write(body);
        }
        final response = await request.close().timeout(const Duration(seconds: 15));
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          // Never forward a token-bearing API POST to another URL.
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (body != null || location == null) throw ProbeFailure('Неожиданный редирект API');
          uri = uri.resolve(location);
          continue;
        }
        final bytes = BytesBuilder();
        await for (final chunk in response.timeout(const Duration(seconds: 15))) {
          bytes.add(chunk);
          if (bytes.length > limit) throw ProbeFailure('Ответ превышает ожидаемый размер');
        }
        return (status: response.statusCode, headers: response.headers, bytes: bytes.takeBytes());
      }
      throw ProbeFailure('Слишком много редиректов');
    } finally {
      client.close(force: true);
    }
  }

  Future<dynamic> api(String method, Map<String, dynamic> args) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final remaining = 500 - DateTime.now().difference(_lastApi).inMilliseconds;
      if (remaining > 0) await Future<void>.delayed(Duration(milliseconds: remaining));
      _lastApi = DateTime.now();
      final form = Uri(queryParameters: {
        ...args.map((k, v) => MapEntry(k, '$v')), 'v': '5.199', 'access_token': token,
      }).query;
      final response = await fetch(Uri.parse('$apiBase$method'), body: form,
          allowLocalTest: apiBase.startsWith('http://127.0.0.1:'));
      if (response.status != 200) throw ProbeFailure('VK API HTTP ${response.status}');
      final decoded = jsonDecode(utf8.decode(response.bytes)) as Map<String, dynamic>;
      if (decoded['error'] != null) {
        final code = (decoded['error'] as Map)['error_code'];
        if (code == 6 && attempt < 2) {
          await Future<void>.delayed(Duration(seconds: attempt + 1));
          continue;
        }
        throw ProbeFailure('VK API code=$code');
      }
      if (!decoded.containsKey('response')) throw ProbeFailure('Нет response у VK API');
      return decoded['response'];
    }
    throw ProbeFailure('VK API: исчерпаны повторы');
  }

  Future<int> send(int peer, Map<String, dynamic> payload, int randomId) async {
    final sent = await api('messages.send', {'peer_ids': peer,
      'random_id': randomId, 'message': '$probePrefix${jsonEncode(payload)}'});
    if (sent is! List || sent.length != 1 || sent.first['error'] != null ||
        sent.first['conversation_message_id'] is! int) {
      throw ProbeFailure('Отправка не подтвердила номер сообщения');
    }
    return sent.first['conversation_message_id'] as int;
  }

  Future<Map<String, dynamic>> receive(Map<String, dynamic> pending,
      Future<void> Function(int) saveCursor) async {
    var cursor = pending['cursor'] as int;
    final end = DateTime.now().add(const Duration(seconds: 65));
    while (DateTime.now().isBefore(end)) {
      final result = await api('messages.getByConversationMessageId', {
        'peer_id': pending['peer'],
        'conversation_message_ids': List.generate(100, (i) => cursor + i + 1).join(','),
      }) as Map;
      final items = List<Map<String, dynamic>>.from(result['items'] as List)
        ..sort((a, b) => (a['conversation_message_id'] as int).compareTo(b['conversation_message_id'] as int));
      for (final message in items) {
        final cmid = message['conversation_message_id'] as int;
        if (message['peer_id'] != pending['peer'] || cmid <= cursor || cmid > cursor + 100) {
          throw ProbeFailure('Некорректный номер сообщения или беседа');
        }
        final payload = responsePayload(message, pending);
        // The caller persists a matched result before moving this cursor.
        if (payload != null) return {'payload': payload, 'message': message, 'cursor': cmid};
      }
      if (items.isNotEmpty) {
        cursor = items.last['conversation_message_id'] as int;
        await saveCursor(cursor);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw ProbeFailure('Ответ не получен за 65 секунд; запрос сохранён для повтора');
  }

  Future<Uint8List> downloadDocument(Map<String, dynamic> received) async {
    final payload = received['payload'] as Map;
    final message = received['message'] as Map;
    final size = payload['size'];
    final hash = payload['sha256'];
    if (size is! int || size < 32 || size > 10 * 1024 * 1024 ||
        hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw ProbeFailure('Некорректное описание тестового файла');
    }
    final docs = (message['attachments'] as List? ?? []).where((a) => a['type'] == 'doc');
    if (docs.isEmpty) throw ProbeFailure('Ответ не содержит документа VK');
    final document = docs.first['doc'] as Map;
    if (document['url'] is! String) throw ProbeFailure('VK не выдал адрес вложения получателю');
    final uri = Uri.parse(document['url'] as String);
    final response = await fetch(uri, limit: size);
    verifyBytes(response.status, response.bytes, size, hash);
    for (final start in [0, 17]) {
      final end = start + 14;
      final part = await fetch(uri, headers: {'Range': 'bytes=$start-$end'}, limit: size);
      if (part.status != 206 ||
          part.headers.value('content-range') != 'bytes $start-$end/$size' ||
          base64Encode(part.bytes) != base64Encode(response.bytes.sublist(start, end + 1))) {
        throw ProbeFailure('HTTP Range не подтверждён со смещения $start');
      }
    }
    return response.bytes;
  }
}

Map<String, dynamic>? responsePayload(Map<String, dynamic> message, Map<String, dynamic> pending) {
  if (message['peer_id'] != pending['peer'] || message['from_id'] != -(pending['group'] as int)) return null;
  final text = message['text'];
  if (text is! String || !text.startsWith(probePrefix)) return null;
  dynamic payload;
  try { payload = jsonDecode(text.substring(probePrefix.length)); } on FormatException { return null; }
  if (payload is! Map<String, dynamic> || payload['role'] != 'server' ||
      payload['run'] != pending['run'] || payload['request'] != pending['request'] ||
      payload['kind'] != 'RESULT') return null;
  return payload;
}

void verifyBytes(int status, List<int> bytes, int size, String hash) {
  if (status != 200 || bytes.length != size || sha256.convert(bytes).toString() != hash) {
    throw ProbeFailure('Файл отклонён: HTTP, размер или SHA-256 не совпали');
  }
}
