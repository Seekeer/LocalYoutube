import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../core/logging/log_service.dart';

class LogsPage extends ConsumerWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LogService logService = ref.watch(logServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('\u041b\u043e\u0433\u0438'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _saveLogs(context, logService),
            icon: const Icon(Icons.save_alt_outlined),
            tooltip:
                '\u0421\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c \u043b\u043e\u0433\u0438',
          ),
          IconButton(
            onPressed: () => logService.clear(),
            icon: const Icon(Icons.delete_outline),
            tooltip:
                '\u041e\u0447\u0438\u0441\u0442\u0438\u0442\u044c \u043b\u043e\u0433\u0438',
          ),
        ],
      ),
      body: StreamBuilder<List<LogEntry>>(
        stream: logService.entriesStream,
        initialData: logService.entries,
        builder:
            (BuildContext context, AsyncSnapshot<List<LogEntry>> snapshot) {
          final List<LogEntry> entries = snapshot.data ?? const <LogEntry>[];
          if (entries.isEmpty) {
            return const Center(
              child: Text(
                '\u041b\u043e\u0433\u043e\u0432 \u043f\u043e\u043a\u0430 \u043d\u0435\u0442',
              ),
            );
          }

          return Column(
            children: <Widget>[
              if (logService.logFilePath != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '\u0424\u0430\u0439\u043b: ${logService.logFilePath}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  reverse: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final LogEntry entry = entries[entries.length - 1 - index];
                    return _LogEntryTile(entry: entry);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveLogs(BuildContext context, LogService logService) async {
    final String? path = await logService.saveSnapshot();
    if (!context.mounted) {
      return;
    }
    final String message = path == null
        ? '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0441\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c \u043b\u043e\u0433\u0438'
        : '\u041b\u043e\u0433\u0438 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u044b: $path';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final TextStyle? baseStyle = Theme.of(context).textTheme.bodySmall;
    final String time = _formatTimestamp(entry.timestampUtc.toLocal());

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                time,
                style: baseStyle,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color:
                      _levelColor(context, entry.level).withValues(alpha: 0.2),
                ),
                child: Text(
                  entry.level.name.toUpperCase(),
                  style: baseStyle?.copyWith(
                    color: _levelColor(context, entry.level),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(entry.message),
          if (entry.error != null) ...<Widget>[
            const SizedBox(height: 6),
            SelectableText(
              'Error: ${entry.error}',
              style: baseStyle?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          if (entry.stackTrace != null) ...<Widget>[
            const SizedBox(height: 6),
            SelectableText(
              entry.stackTrace!,
              style: baseStyle?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }

  Color _levelColor(BuildContext context, LogLevel level) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    switch (level) {
      case LogLevel.debug:
        return colors.secondary;
      case LogLevel.info:
        return colors.primary;
      case LogLevel.warning:
        return colors.tertiary;
      case LogLevel.error:
        return colors.error;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final String year = timestamp.year.toString().padLeft(4, '0');
    final String month = twoDigits(timestamp.month);
    final String day = twoDigits(timestamp.day);
    final String hour = twoDigits(timestamp.hour);
    final String minute = twoDigits(timestamp.minute);
    final String second = twoDigits(timestamp.second);
    final String millis = timestamp.millisecond.toString().padLeft(3, '0');
    return '$year-$month-$day $hour:$minute:$second.$millis';
  }
}
