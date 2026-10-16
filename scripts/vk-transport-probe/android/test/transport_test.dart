import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vk_transport_probe/transport.dart';

void main() {
  test('correlation rejects other identities and requests, accepts matching response', () {
    final pending = {'peer': 2000000001, 'group': 42, 'run': 'run', 'request': 'request'};
    final payload = {'role': 'server', 'run': 'run', 'request': 'request', 'kind': 'RESULT'};
    final message = {'peer_id': 2000000001, 'from_id': -42, 'text': '$probePrefix${jsonEncode(payload)}'};
    expect(responsePayload(message, pending), payload);
    expect(responsePayload({...message, 'from_id': -43}, pending), isNull);
    expect(responsePayload({...message, 'peer_id': 2000000002}, pending), isNull);
    expect(responsePayload(message, {...pending, 'request': 'other'}), isNull);
    expect(responsePayload({...message, 'text': '${probePrefix}broken'}, pending), isNull);
  });

  test('HTML HTTP 200, truncated and modified files cannot become offline files', () {
    final original = utf8.encode('this represents the exact expected video');
    final hash = sha256.convert(original).toString();
    verifyBytes(200, original, original.length, hash);
    expect(() => verifyBytes(200, utf8.encode('<html>page</html>'), original.length, hash), throwsA(isA<ProbeFailure>()));
    expect(() => verifyBytes(200, original.sublist(1), original.length, hash), throwsA(isA<ProbeFailure>()));
    expect(() => verifyBytes(200, List.filled(original.length, 0), original.length, hash), throwsA(isA<ProbeFailure>()));
  });

  test('token is a POST body; an API redirect is rejected without forwarding it', () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(() => server.close(force: true));
    var calls = 0;
    server.listen((request) async {
      calls++;
      expect(request.uri.query, isEmpty);
      expect(request.method, 'POST');
      final form = Uri.splitQueryString(await utf8.decoder.bind(request).join());
      expect(form['access_token'], 'non-secret-fixture');
      request.response.statusCode = 302;
      request.response.headers.set('location', 'http://127.0.0.1:${server.port}/leak');
      await request.response.close();
    });
    final net = NativeTransport('non-secret-fixture', apiBase: 'http://127.0.0.1:${server.port}/');
    await expectLater(net.api('groups.getById', {}), throwsA(isA<ProbeFailure>()));
    expect(calls, 1);
  });
}
