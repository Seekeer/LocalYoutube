import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/app_updates/windows_applier_launcher.dart';

void main() {
  test('hidden applier survives its launcher and preserves path arguments',
      () async {
    final root = await Directory.systemTemp.createTemp("LocalTube update ' ");
    final started = File('${root.path}/started.json');
    final release = File('${root.path}/release');
    final finished = File('${root.path}/finished');
    final script = File('${root.path}/applier.ps1');
    final value = "${root.path}/папка ' с пробелами/file.txt";
    await script.writeAsString(r'''
param([string]$Started, [string]$Release, [string]$Finished, [string]$Value, [string]$StartupSignal)
Start-Sleep -Milliseconds 1500
[IO.File]::WriteAllText($StartupSignal, 'started')
@{value=$Value; pid=$PID} | ConvertTo-Json | Set-Content -LiteralPath $Started -Encoding UTF8
for ($i=0; $i -lt 200 -and -not (Test-Path -LiteralPath $Release); $i++) {
  Start-Sleep -Milliseconds 100
}
[IO.File]::WriteAllText($Finished, 'finished')
''');
    Future<void> waitFor(File file) async {
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while (!await file.exists()) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Applier did not create ${file.path}');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    try {
      await launchWindowsApplier(script.path, <String, String>{
        'Started': started.path,
        'Release': release.path,
        'Finished': finished.path,
        'Value': value,
      });
      await waitFor(started);
      final record =
          jsonDecode((await started.readAsString()).replaceFirst('\uFEFF', ''));
      expect(record['value'], value);
      expect(await finished.exists(), isFalse);
    } finally {
      await release.writeAsString('release');
      await waitFor(finished);
      await root.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);

  test('rejects an applier that exits during startup', () async {
    final root = await Directory.systemTemp.createTemp('applier_failure_');
    try {
      final script = File('${root.path}/fail.ps1');
      await script.writeAsString('param([string]\$StartupSignal)\n'
          'Start-Sleep -Milliseconds 1500\nexit 1');
      await expectLater(launchWindowsApplier(script.path, <String, String>{}),
          throwsStateError);
    } finally {
      await root.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);
}
