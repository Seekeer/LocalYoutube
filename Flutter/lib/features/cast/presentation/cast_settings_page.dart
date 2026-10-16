import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cast_controller.dart';

/// Where this device is made available as a Receiver, and where it is given a name.
///
/// Receiver Mode lives here rather than being worked out from the device: LocalTube is one Android
/// application, and which installation should act as one is something only the person knows.
class CastSettingsPage extends ConsumerStatefulWidget {
  const CastSettingsPage({super.key});

  static const String title = 'Cast';
  static const String receiverModeTitle = 'Receiver Mode';
  static const String receiverModeDescription =
      'Offer this device as a Receiver. It is available only while LocalTube '
      'is open on it.';
  static const String deviceNameLabel = 'Device name';
  static const String deviceNameHelper =
      'Leave it empty to be named after the Android device model.';
  static const String saveNameLabel = 'Save name';

  static const Key receiverModeSwitchKey = Key('receiver-mode-switch');
  static const Key deviceNameFieldKey = Key('cast-device-name-field');
  static const Key saveNameButtonKey = Key('cast-save-name-button');

  @override
  ConsumerState<CastSettingsPage> createState() => _CastSettingsPageState();
}

class _CastSettingsPageState extends ConsumerState<CastSettingsPage> {
  final TextEditingController _nameController = TextEditingController();

  /// While the person is typing, the field is theirs: a registration arriving in the background
  /// must not overwrite a half-finished name.
  bool _isNameEdited = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = ref.read(castControllerProvider).deviceName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CastUiState>(castControllerProvider, (
      CastUiState? previous,
      CastUiState next,
    ) {
      if (!_isNameEdited && next.deviceName != _nameController.text) {
        _nameController.text = next.deviceName;
      }
    });

    final CastUiState state = ref.watch(castControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(CastSettingsPage.title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: <Widget>[
          SwitchListTile(
            key: CastSettingsPage.receiverModeSwitchKey,
            contentPadding: EdgeInsets.zero,
            value: state.isReceiverMode,
            title: const Text(CastSettingsPage.receiverModeTitle),
            subtitle: const Text(CastSettingsPage.receiverModeDescription),
            onChanged: (bool value) => unawaited(
              ref.read(castControllerProvider.notifier).setReceiverMode(value),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: CastSettingsPage.deviceNameFieldKey,
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: CastSettingsPage.deviceNameLabel,
              helperText: CastSettingsPage.deviceNameHelper,
              border: OutlineInputBorder(),
            ),
            onChanged: (String _) {
              if (!_isNameEdited) {
                setState(() {
                  _isNameEdited = true;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: CastSettingsPage.saveNameButtonKey,
              onPressed: () => unawaited(_saveName()),
              child: const Text(CastSettingsPage.saveNameLabel),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveName() async {
    await ref
        .read(castControllerProvider.notifier)
        .renameDevice(_nameController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _isNameEdited = false;
    });
    _nameController.text = ref.read(castControllerProvider).deviceName;
  }
}
