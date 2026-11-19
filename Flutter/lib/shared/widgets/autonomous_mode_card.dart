import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../core/network/network_status.dart';
import '../../core/playback/playback_mode.dart';
import 'lt_widgets.dart';

/// «Автономный режим»: only what is on the phone, no requests to the server.
/// The same row on the main menu and on «Скачанное», so the switch always
/// says what it does.
class AutonomousModeCard extends ConsumerWidget {
  const AutonomousModeCard({super.key});

  static const String title = 'Автономный режим';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = Theme.of(context).textTheme;
    final LtPalette palette = LtPalette.of(context);
    final bool internetEnabled =
        ref.watch(networkStatusProvider).value != NetworkStatus.offline;
    final bool value = ref.watch(effectiveAutonomousModeProvider);
    final ValueChanged<bool>? onChanged = internetEnabled
        ? (bool next) =>
            ref.read(manualAutonomousModeProvider.notifier).state = next
        : null;
    final String hint = !internetEnabled
        ? 'Нет сети — только скачанное'
        : value
            ? 'Включён — только скачанное'
            : 'Выключен — сервер на связи';
    return Card(
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: <Widget>[
              // Neutral while off; mint («only what is on the phone») while on.
              LtToneIcon(
                icon: value ? Icons.cloud_off_rounded : Icons.cloud_outlined,
                tone: value
                    ? palette.mint
                    : LtTone(
                        strong: Theme.of(context).colorScheme.onSurfaceVariant,
                        soft: Theme.of(context).colorScheme.surfaceContainerHigh,
                      ),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: text.titleMedium),
                    Text(hint, style: text.bodySmall),
                  ],
                ),
              ),
              Switch(
                key: const Key('autonomous-mode-switch'),
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
