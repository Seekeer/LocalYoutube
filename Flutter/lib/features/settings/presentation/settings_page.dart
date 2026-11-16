import 'package:flutter/material.dart';

import '../../app_updates/app_updates.dart';

/// Application settings. Holds the update card: installed version and
/// channel, the check, its status, download and installation.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: SafeArea(
        child: ListView(
          children: const <Widget>[
            Padding(
              padding: EdgeInsets.all(16),
              child: AppUpdatesMenu(),
            ),
          ],
        ),
      ),
    );
  }
}
