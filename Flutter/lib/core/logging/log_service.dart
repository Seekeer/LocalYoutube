import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LogEntry {
  const LogEntry({
    required this.timestampUtc,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestampUtc;
  final LogLevel level;
  final String message;
  final String? error;
  final String? stackTrace;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestampUtc': timestampUtc.toIso8601String(),
      'level': level.name,
      'message': message,
      if (error != null) 'error': error,
      if (stackTrace != null) 'stackTrace': stackTrace,
    };
  }

  static LogEntry? tryParseJsonLine(String line) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return null;
      }
      final Map<String, dynamic> map = decoded.cast<String, dynamic>();
      final DateTime timestampUtc =
          DateTime.tryParse(map['timestampUtc']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc();
      final String levelValue = map['level']?.toString() ?? '';
      final LogLevel level = LogLevel.values.firstWhere(
        (LogLevel value) => value.name == levelValue,
        orElse: () => LogLevel.info,
      );
      return LogEntry(
        timestampUtc: timestampUtc,
        level: level,
        message: map['message']?.toString() ?? '',
        error: map['error']?.toString(),
        stackTrace: map['stackTrace']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class LogService {
  LogService({
    this.maxInMemoryEntries = 500,
    this.maxFileSizeBytes = 1024 * 1024,
    this.fileName = 'localtube.log',
    this.minimumLevel = LogLevel.debug,
    Directory? logDirectory,
    Directory? exportDirectory,
    bool? isAndroidOverride,
  })  : _logDirectory = logDirectory,
        _exportDirectory = exportDirectory,
        _isAndroidOverride = isAndroidOverride,
        _logger = Logger(
          printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 8,
            lineLength: 120,
            colors: false,
          ),
        );

  static final RegExp _authorizationPattern = RegExp(
    r'''(authorization["']?\s*[:=]\s*["']?bearer\s+)([^\s,"'}]+)''',
    caseSensitive: false,
  );
  static final RegExp _bearerPattern = RegExp(
    r'(bearer\s+)([A-Za-z0-9\-._~+/]+=*)',
    caseSensitive: false,
  );
  static final RegExp _querySecretPattern = RegExp(
    r'([?&](?:access|refresh|id)?_?token=|[?&](?:password|secret|api[_-]?key)=)([^&\s]+)',
    caseSensitive: false,
  );
  static final RegExp _jsonSecretPattern = RegExp(
    r'("(?:(?:access|refresh|id)_?token|password|secret|api[_-]?key)"\s*:\s*")([^"]+)(")',
    caseSensitive: false,
  );
  static final RegExp _keyValueSecretPattern = RegExp(
    r'''\b((?:access|refresh|id)_?token|password|secret|api[_-]?key)\b(\s*[:=]\s*["']?)([^,\s"'}&]+)''',
    caseSensitive: false,
  );

  final Logger _logger;
  final Directory? _logDirectory;
  final Directory? _exportDirectory;
  final bool? _isAndroidOverride;
  final ListQueue<LogEntry> _entries = ListQueue<LogEntry>();
  final StreamController<List<LogEntry>> _entriesController =
      StreamController<List<LogEntry>>.broadcast();

  final int maxInMemoryEntries;
  final int maxFileSizeBytes;
  final String fileName;
  final LogLevel minimumLevel;

  bool _isInitialized = false;
  File? _logFile;
  Future<void> _writeQueue = Future<void>.value();

  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);
  Stream<List<LogEntry>> get entriesStream => _entriesController.stream;
  String? get logFilePath => _logFile?.path;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;

    try {
      final Directory baseDir =
          _logDirectory ?? await getApplicationSupportDirectory();
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final File file =
          File('${baseDir.path}${Platform.pathSeparator}$fileName');
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      _logFile = file;

      await _restoreInMemoryBuffer(file);
      _emitSnapshot();
    } catch (error, stackTrace) {
      _logger.w('Log file initialization failed: $error');
      _logger.d(stackTrace.toString());
    }
  }

  Future<void> flush() => _writeQueue;

  Future<String?> saveSnapshot() async {
    await flush();

    final File? file = _logFile;
    if (file == null) {
      return null;
    }

    try {
      final Directory directory = await _resolveExportDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final DateTime now = DateTime.now().toUtc();
      final String timestamp = _fileTimestamp(now);
      final File snapshot = File(
        '${directory.path}${Platform.pathSeparator}localtube_$timestamp.log',
      );
      await file.copy(snapshot.path);
      return snapshot.path;
    } catch (error, stackTrace) {
      _logger.w('Failed to save log snapshot: $error');
      _logger.d(stackTrace.toString());
      return null;
    }
  }

  Future<void> clear() async {
    _entries.clear();
    _emitSnapshot();

    final File? file = _logFile;
    if (file == null) {
      return;
    }

    _writeQueue = _writeQueue.then((_) async {
      try {
        await file.writeAsString('', mode: FileMode.write, flush: true);
      } catch (error, stackTrace) {
        _logger.w('Failed to clear log file: $error');
        _logger.d(stackTrace.toString());
      }
    });

    await _writeQueue;
  }

  String sanitize(String value) => _sanitize(value);

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warn(String message) => _log(LogLevel.warning, message);
  void error(String message, Object error, StackTrace stackTrace) {
    _log(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimumLevel.index) {
      return;
    }
    if (kReleaseMode && level == LogLevel.debug) {
      return;
    }

    final LogEntry entry = LogEntry(
      timestampUtc: DateTime.now().toUtc(),
      level: level,
      message: _sanitize(message),
      error: error == null ? null : _sanitize(error.toString()),
      stackTrace: stackTrace == null ? null : _sanitize(stackTrace.toString()),
    );

    if (_entries.length >= maxInMemoryEntries) {
      _entries.removeFirst();
    }
    _entries.addLast(entry);
    _emitSnapshot();
    _printToConsole(entry);
    _persistEntry(entry);
  }

  void _printToConsole(LogEntry entry) {
    final String prefix =
        '[${entry.timestampUtc.toIso8601String()}][${entry.level.name.toUpperCase()}]';
    final String message = '$prefix ${entry.message}';

    switch (entry.level) {
      case LogLevel.debug:
        _logger.d(message);
        break;
      case LogLevel.info:
        _logger.i(message);
        break;
      case LogLevel.warning:
        _logger.w(message);
        break;
      case LogLevel.error:
        _logger.e(
          message,
          error: entry.error,
          stackTrace: entry.stackTrace == null
              ? null
              : StackTrace.fromString(entry.stackTrace!),
        );
        break;
    }
  }

  void _persistEntry(LogEntry entry) {
    final File? file = _logFile;
    if (file == null) {
      return;
    }

    final String line = jsonEncode(entry.toJson());
    _writeQueue = _writeQueue.then((_) async {
      try {
        await file.writeAsString(
          '$line\n',
          mode: FileMode.append,
          flush: false,
        );
        await _truncateFileIfNeeded(file);
      } catch (error, stackTrace) {
        _logger.w('Failed to persist log entry: $error');
        _logger.d(stackTrace.toString());
      }
    });
  }

  Future<void> _restoreInMemoryBuffer(File file) async {
    final List<String> lines = await file.readAsLines();
    final int start = lines.length > maxInMemoryEntries
        ? lines.length - maxInMemoryEntries
        : 0;
    for (int index = start; index < lines.length; index++) {
      final LogEntry? parsed = LogEntry.tryParseJsonLine(lines[index]);
      if (parsed == null) {
        continue;
      }
      if (_entries.length >= maxInMemoryEntries) {
        _entries.removeFirst();
      }
      _entries.addLast(parsed);
    }
  }

  Future<void> _truncateFileIfNeeded(File file) async {
    final int size = await file.length();
    if (size <= maxFileSizeBytes) {
      return;
    }

    final List<String> lines = await file.readAsLines();
    final List<String> retained = <String>[];
    int retainedBytes = 0;

    for (int index = lines.length - 1; index >= 0; index--) {
      final String line = lines[index].trimRight();
      if (line.isEmpty) {
        continue;
      }
      final int lineBytes = utf8.encode('$line\n').length;
      if (retainedBytes + lineBytes > maxFileSizeBytes) {
        break;
      }
      retained.add(line);
      retainedBytes += lineBytes;
    }

    final String nextContent = retained.reversed.join('\n');
    await file.writeAsString(
      nextContent.isEmpty ? '' : '$nextContent\n',
      mode: FileMode.write,
      flush: true,
    );
  }

  String _sanitize(String source) {
    if (source.isEmpty) {
      return source;
    }

    String sanitized = source;
    sanitized = sanitized.replaceAllMapped(
      _authorizationPattern,
      (Match match) => '${match.group(1)}***',
    );
    sanitized = sanitized.replaceAllMapped(
      _bearerPattern,
      (Match match) => '${match.group(1)}***',
    );
    sanitized = sanitized.replaceAllMapped(
      _querySecretPattern,
      (Match match) => '${match.group(1)}***',
    );
    sanitized = sanitized.replaceAllMapped(
      _jsonSecretPattern,
      (Match match) => '${match.group(1)}***${match.group(3)}',
    );
    sanitized = sanitized.replaceAllMapped(
      _keyValueSecretPattern,
      (Match match) => '${match.group(1)}${match.group(2)}***',
    );
    return sanitized;
  }

  void _emitSnapshot() {
    if (_entriesController.isClosed) {
      return;
    }
    _entriesController.add(List<LogEntry>.unmodifiable(_entries));
  }

  String _fileTimestamp(DateTime timestampUtc) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final String year = timestampUtc.year.toString().padLeft(4, '0');
    final String month = twoDigits(timestampUtc.month);
    final String day = twoDigits(timestampUtc.day);
    final String hour = twoDigits(timestampUtc.hour);
    final String minute = twoDigits(timestampUtc.minute);
    final String second = twoDigits(timestampUtc.second);
    return '$year$month${day}_$hour$minute$second';
  }

  Future<Directory> _resolveExportDirectory() async {
    if (_exportDirectory != null) {
      return _exportDirectory;
    }

    final bool isAndroid = _isAndroidOverride ?? Platform.isAndroid;

    if (isAndroid) {
      final List<Directory>? downloadDirectories =
          await getExternalStorageDirectories(type: StorageDirectory.downloads);
      final Directory? downloadsDirectory =
          downloadDirectories == null || downloadDirectories.isEmpty
              ? null
              : downloadDirectories.first;
      if (downloadsDirectory != null) {
        return Directory(
          '${downloadsDirectory.path}${Platform.pathSeparator}LocalTubeLogs',
        );
      }

      final Directory? externalDirectory = await getExternalStorageDirectory();
      if (externalDirectory != null) {
        return Directory(
          '${externalDirectory.path}${Platform.pathSeparator}LocalTubeLogs',
        );
      }
    }

    try {
      final Directory? downloadsDirectory = await getDownloadsDirectory();
      if (downloadsDirectory != null) {
        return Directory(
          '${downloadsDirectory.path}${Platform.pathSeparator}LocalTubeLogs',
        );
      }
    } on UnsupportedError {
      // Some platforms expose no downloads directory through path_provider.
    }

    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    return Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}LocalTubeLogs',
    );
  }
}
