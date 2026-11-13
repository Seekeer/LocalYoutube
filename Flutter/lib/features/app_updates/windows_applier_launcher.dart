import 'dart:convert';
import 'dart:io';

String _literal(String value) => "'${value.replaceAll("'", "''")}'";

String _encoded(String command) => base64Encode(<int>[
      for (final unit in command.codeUnits) ...<int>[unit & 255, unit >> 8],
    ]);

/// Windows PowerShell exits before executing -File when Dart starts it in
/// detached mode without usable console handles. Let a normal PowerShell
/// process create the independent, hidden applier instead.
Future<void> launchWindowsApplier(
    String script, Map<String, String> parameters) async {
  final startup = await Directory.systemTemp.createTemp('localtube-applier-');
  final signal = '${startup.path}${Platform.pathSeparator}started';
  final arguments = <String, String>{...parameters, 'StartupSignal': signal};
  final invocation =
      '\$parameters = @{${arguments.entries.map((entry) => '${_literal(entry.key)} = ${_literal(entry.value)}').join('; ')}}; '
      '& ${_literal(script)} @parameters';
  final launcher = '\$ErrorActionPreference = \'Stop\'; '
      '\$child = Start-Process -FilePath \'powershell.exe\' -WindowStyle Hidden '
      '-ArgumentList @(\'-NoProfile\', \'-NonInteractive\', \'-ExecutionPolicy\', '
      '\'Bypass\', \'-EncodedCommand\', ${_literal(_encoded(invocation))}) -PassThru; '
      '\$deadline = [DateTime]::UtcNow.AddSeconds(15); '
      'try { while (-not (Test-Path -LiteralPath ${_literal(signal)})) { '
      '\$child.Refresh(); '
      'if (\$child.HasExited) { throw \'Update applier exited during startup\' }; '
      'if ([DateTime]::UtcNow -ge \$deadline) { throw \'Update applier startup timed out\' }; '
      'Start-Sleep -Milliseconds 100 '
      '} } catch { if (-not \$child.HasExited) { \$child.Kill() }; throw }';
  try {
    final result = await Process.run('powershell.exe', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-EncodedCommand',
      _encoded(launcher),
    ]);
    if (result.exitCode != 0) {
      throw StateError('Windows update applier could not start');
    }
  } finally {
    await startup.delete(recursive: true);
  }
}
