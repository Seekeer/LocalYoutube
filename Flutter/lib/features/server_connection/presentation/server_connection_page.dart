import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/config/server_connection.dart';

class ServerConnectionPage extends StatefulWidget {
  const ServerConnectionPage({super.key, this.initial, required this.onSave});
  final ServerConnection? initial;
  final Future<void> Function(ServerConnection) onSave;

  @override
  State<ServerConnectionPage> createState() => _ServerConnectionPageState();
}

class _ServerConnectionPageState extends State<ServerConnectionPage> {
  final _address = TextEditingController();
  final _localHost = TextEditingController();
  final _localPort = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _fill(widget.initial!);
  }

  void _fill(ServerConnection connection) {
    _address.text = connection.apiBaseUrl;
    _localHost.text = connection.localApiHost;
    _localPort.text =
        connection.localApiPort == 0 ? '' : '${connection.localApiPort}';
  }

  @override
  void dispose() {
    _address.dispose();
    _localHost.dispose();
    _localPort.dispose();
    super.dispose();
  }

  Future<void> _importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.size > 16384) {
        throw const FormatException('Файл конфигурации слишком большой.');
      }
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final connection = ServerConnection.parse(utf8.decode(bytes));
      if (mounted) {
        setState(() {
          _fill(connection);
          _error = null;
        });
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _scan() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScannerPage()),
    );
    if (value == null || !mounted) return;
    try {
      final connection = ServerConnection.parse(value);
      setState(() {
        _fill(connection);
        _error = null;
      });
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (mounted) {
      setState(() {
        _error = error is FormatException
            ? error.message
            : 'Не удалось прочитать или сохранить настройки. Попробуйте ещё раз.';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final portText = _localPort.text.trim();
      final port = portText.isEmpty ? 0 : int.tryParse(portText);
      if (port == null) throw const FormatException('Порт должен быть числом.');
      final connection = ServerConnection(
        apiBaseUrl: _address.text,
        localApiHost: _localHost.text,
        localApiPort: port,
      );
      await widget.onSave(connection);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Подключение к серверу')),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                    'Введите адрес API или импортируйте конфиг из раздела «Мобильное приложение» на вашем сервере.'),
                const SizedBox(height: 20),
                TextField(
                    controller: _address,
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                        labelText: 'Адрес API',
                        hintText: 'https://server.example:9999')),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  OutlinedButton.icon(
                      onPressed: _busy ? null : _importFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Открыть конфиг')),
                  if (Platform.isAndroid || Platform.isIOS)
                    OutlinedButton.icon(
                        onPressed: _busy ? null : _scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Сканировать QR')),
                ]),
                ExpansionTile(
                    title: const Text('Локальная сеть (необязательно)'),
                    children: [
                      TextField(
                          controller: _localHost,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                              labelText: 'Локальный адрес')),
                      TextField(
                          controller: _localPort,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Локальный порт')),
                    ]),
                const SizedBox(height: 12),
                const Text(
                    'Проверьте адрес перед сохранением. После сохранения войдите в свой аккаунт на этом сервере.'),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(
                        _busy ? 'Сохранение…' : 'Сохранить и подключиться')),
              ]),
        )),
      );
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _returned = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('QR-код сервера')),
        body: MobileScanner(
            controller: _controller,
            errorBuilder: (_, error) => const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Камера недоступна. Разрешите доступ к камере в настройках устройства или откройте JSON-конфиг.'))),
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (!_returned && value != null) {
                  _returned = true;
                  Navigator.of(context).pop(value);
                  break;
                }
              }
            }),
      );
}
