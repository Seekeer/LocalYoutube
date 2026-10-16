import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

import 'transport.dart';

void main() => runApp(const MaterialApp(home: ProbePage()));

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});
  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  final token = TextEditingController();
  final group = TextEditingController(text: '242343342');
  final peer = TextEditingController(text: '2000000001');
  final operator = TextEditingController();
  final instance = nonce();
  final folder = Directory('${Directory.systemTemp.path}/localtube_vk_probe');
  Map<String, dynamic> saved = {};
  Map<String, dynamic> report = {};
  bool whitelist = false, busy = false;
  String status = 'Вставьте ключ Test LT1. Он используется только на телефоне и не сохраняется.';
  File get stateFile => File('${folder.path}/state.json');

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    await folder.create(recursive: true);
    if (await stateFile.exists()) {
      saved = jsonDecode(await stateFile.readAsString()) as Map<String, dynamic>;
      report = Map<String, dynamic>.from(saved['report'] as Map? ?? {});
    }
    if (mounted) setState(() {});
  }

  Future<void> persist() async {
    saved['report'] = report;
    final partial = File('${stateFile.path}.partial');
    await partial.writeAsString(jsonEncode(saved), flush: true);
    await partial.rename(stateFile.path);
  }

  Future<void> guarded(Future<void> Function(NativeTransport) action) async {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { busy = true; status = 'Проверка…'; });
    final net = NativeTransport(token.text.trim());
    try {
      if (net.token.isEmpty) throw ProbeFailure('Вставьте ключ сообщества Test LT1');
      await action(net);
    } catch (error) {
      final safe = error is ProbeFailure ? error.message : 'Ошибка ${error.runtimeType}; приватные данные скрыты';
      report['last_error'] = safe;
      await persist();
      status = safe;
    } finally {
      report['hosts'] = {...List<String>.from(report['hosts'] as List? ?? []), ...net.hosts}.toList()..sort();
      await persist();
      if (mounted) setState(() { busy = false; });
    }
  }

  Future<Map<String, dynamic>> sendNew(NativeTransport net, String command,
      {String? target, bool delayed = false}) async {
    final pending = <String, dynamic>{
      'run': nonce(), 'request': nonce(), 'command': command, 'role': 'client',
      'peer': int.parse(peer.text), 'group': int.parse(group.text),
      'random_id': Random.secure().nextInt(0x7ffffffe) + 1,
      'cursor': 0, 'sender_instance': instance, 'sender_pid': pid,
      if (target != null) 'result_for': target,
      if (delayed) 'delay_seconds': 15,
    };
    saved['pending'] = pending;
    await persist();
    pending['cursor'] = await net.send(pending['peer'] as int, pending, pending['random_id'] as int);
    await persist();
    return pending;
  }

  Future<Map<String, dynamic>> receive(NativeTransport net, Map<String, dynamic> pending) async {
    // If a process died before the send acknowledgement was saved, retry with
    // the original transport ID. Logical request identity is also unchanged.
    if (pending['cursor'] == 0) {
      pending['cursor'] = await net.send(pending['peer'] as int, pending, pending['random_id'] as int);
      await persist();
    }
    final received = await net.receive(pending, (cursor) async {
      pending['cursor'] = cursor;
      await persist();
    });
    // Save result before advancing the receiving cursor; the URL stays private.
    saved['received'] = received;
    await persist();
    pending['cursor'] = received['cursor'];
    await persist();
    return received;
  }

  Future<void> run(NativeTransport net) async {
    report = {'probe': 'LT-ANDROID-PROBE/1', 'platform': Platform.operatingSystem,
      'os': Platform.operatingSystemVersion, 'dart': Platform.version.split(' ').first,
      'started_utc': DateTime.now().toUtc().toIso8601String(),
      'whitelist_user_confirmed': whitelist, 'operator_user_entered': operator.text.trim(),
      'scope': 'Synthetic catalog; native dart:io API and small MP4. No LocalTube player or large-file test.'};
    try {
      final response = await net.fetch(Uri.parse('https://api.localtube.sekeerserveri3.duckdns.org:9999/'), limit: 1024 * 1024);
      report['production_control'] = 'reachable_http_${response.status}';
    } catch (_) {
      report['production_control'] = 'unreachable_or_timeout';
    }
    final own = await net.api('groups.getById', {});
    final groups = own is List ? own : own['groups'] as List;
    if (groups.length != 1 || groups.first['id'] != int.parse(group.text)) throw ProbeFailure('Ключ другого сообщества');
    report['own_group'] = 'pass';
    final initial = await sendNew(net, 'LIST_RECENT');
    final first = await receive(net, initial);
    final payload = first['payload'] as Map;
    if (payload['status'] != 'ready' || payload['prepared_count'] != 1) throw ProbeFailure('Неверный ответ ответчика');
    report['round_trip'] = 'pass';
    final data = await net.downloadDocument(first);
    final partial = File('${folder.path}/sample.partial');
    await partial.writeAsBytes(data, flush: true);
    await partial.rename('${folder.path}/sample.mp4');
    report['download_sha256'] = 'pass';
    report['range_start_and_offset'] = 'pass';
    report['sample_size'] = data.length;
    saved['sample_sha256'] = payload['sha256'];

    // A fresh transport send with the same logical ID must reach the responder.
    initial['random_id'] = Random.secure().nextInt(0x7ffffffe) + 1;
    initial['cursor'] = await net.send(initial['peer'] as int, initial, initial['random_id'] as int);
    await persist();
    final duplicate = (await receive(net, initial))['payload'] as Map;
    if (duplicate['prepared_count'] != 1 || duplicate['duplicate'] != true ||
        duplicate['sha256'] != payload['sha256']) throw ProbeFailure('Повтор не вернул сохранённый результат');
    report['duplicate_request'] = 'pass';
    saved['original_request'] = initial['request'];
    final query = await sendNew(net, 'GET_STATUS', target: initial['request'] as String);
    final answer = (await receive(net, query))['payload'] as Map;
    if (answer['sha256'] != payload['sha256'] || answer['prepared_count'] != 1) throw ProbeFailure('Статус не восстановлен');
    report['status_after_new_request'] = 'pass';
    report['last_error'] = null;
    status = 'Команды, повтор, статус, SHA-256 и Range прошли. Теперь проверьте ответ после закрытия приложения.';
  }

  Future<void> scheduleRecovery(NativeTransport net) async {
    await sendNew(net, 'LIST_RECENT', delayed: true);
    status = 'Запрос отправлен. Полностью закройте приложение, подождите 20 секунд, откройте снова, вставьте ключ и нажмите «Получить сохранённый ответ».';
  }

  Future<void> recover(NativeTransport net) async {
    if (saved['pending'] is! Map) throw ProbeFailure('Нет сохранённого запроса');
    final pending = Map<String, dynamic>.from(saved['pending'] as Map);
    saved['pending'] = pending;
    final reply = await receive(net, pending);
    if ((reply['payload'] as Map)['status'] != 'ready') throw ProbeFailure('Ответ не готов');
    report['reply_after_new_client_runtime'] = pending['sender_instance'] != instance ? 'pass' : 'same_runtime_not_proven';
    report['os_pid_changed'] = pending['sender_pid'] != pid;
    status = 'Сохранённый ответ получен. Новый запуск клиента: ${report['reply_after_new_client_runtime']}';
  }

  Future<void> checkLocal() async {
    final file = File('${folder.path}/sample.mp4');
    final valid = await file.exists() && sha256.convert(await file.readAsBytes()).toString() == saved['sample_sha256'];
    report['saved_file_recheck'] = valid ? 'pass' : 'not_available';
    await persist();
    if (mounted) setState(() { status = valid ? 'Сохранённый файл цел и доступен без сети. Воспроизведение этот APK не проверяет.' : 'Сначала выполните полную проверку файла.'; });
  }

  @override
  void dispose() { token.dispose(); group.dispose(); peer.dispose(); operator.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('LocalTube VK Probe')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Отдельная тестовая программа. Каталог синтетический. Ключ не встроен в APK, не сохраняется и не попадает в отчёт.'),
      TextField(controller: token, obscureText: true, autocorrect: false, enableSuggestions: false,
        decoration: const InputDecoration(labelText: 'Ключ Test LT1')),
      TextField(controller: group, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ID сообщества')),
      TextField(controller: peer, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'peer_id тестовой беседы')),
      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Сейчас активны белые списки'), value: whitelist,
        onChanged: busy ? null : (v) => setState(() { whitelist = v ?? false; })),
      TextField(controller: operator, decoration: const InputDecoration(labelText: 'Оператор / сеть (по желанию)')),
      const SizedBox(height: 12),
      FilledButton(onPressed: busy ? null : () => guarded(run), child: const Text('1. Проверить команды и файл')),
      OutlinedButton(onPressed: busy ? null : () => guarded(scheduleRecovery), child: const Text('2. Отправить ответ с задержкой')),
      OutlinedButton(onPressed: busy ? null : () => guarded(recover), child: const Text('3. Получить сохранённый ответ')),
      OutlinedButton(onPressed: busy ? null : checkLocal, child: const Text('Проверить файл без сети')),
      OutlinedButton(onPressed: busy ? null : () async {
        await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(report)));
        if (mounted) setState(() { status = 'Безопасный отчёт скопирован; можно прислать его в чат.'; });
      }, child: const Text('Скопировать отчёт')),
      if (busy) const LinearProgressIndicator(),
      const SizedBox(height: 16), SelectableText(status),
      const SizedBox(height: 16), SelectableText(const JsonEncoder.withIndent('  ').convert(report)),
    ]),
  );
}
