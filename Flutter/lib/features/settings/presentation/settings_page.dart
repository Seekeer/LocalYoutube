import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/theme_mode_controller.dart';
import '../../../shared/widgets/lt_widgets.dart';
import '../../app_updates/app_updates.dart';
import '../../auth/presentation/sign_out.dart';

/// The name the person signed in with, as the login screen saved it.
final AutoDisposeFutureProvider<String?> _signedInNameProvider =
    FutureProvider.autoDispose<String?>((Ref ref) async {
  try {
    final String? name =
        await ref.read(secureStorageServiceProvider).read('saved_login');
    return (name ?? '').trim().isEmpty ? null : name!.trim();
  } catch (_) {
    return null;
  }
});

/// Application settings: the update card (installed version and channel, the
/// check, download and installation), the theme, this device's Cast settings
/// and logs, and signing out.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final LtPalette palette = LtPalette.of(context);
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final String? userName = ref.watch(_signedInNameProvider).valueOrNull;
    String server = '';
    try {
      server = Uri.parse(ref.read(appConfigProvider).apiBaseUrl).host;
    } catch (_) {
      server = '';
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        bottom: _isSigningOut
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ListView(
        padding: ltListPadding(
          context,
          top: 0,
          horizontal: LtSizes.gutter,
        ),
        children: <Widget>[
          const LtSectionHeader(
            'Приложение',
            padding: EdgeInsets.fromLTRB(0, 8, 0, 10),
          ),
          const AppUpdatesMenu(),
          const LtSectionHeader('Оформление'),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: SegmentedButton<ThemeMode>(
              key: const Key('settings-theme'),
              showSelectedIcon: false,
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Авто'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Светлая'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Тёмная'),
                ),
              ],
              selected: <ThemeMode>{themeMode},
              onSelectionChanged: (Set<ThemeMode> selected) =>
                  ref.read(themeModeProvider.notifier).select(selected.first),
            ),
          ),
          const LtSectionHeader('Устройства и логи'),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  key: const Key('settings-cast'),
                  leading: LtToneIcon(
                    icon: Icons.cast_rounded,
                    tone: palette.cobalt,
                    size: 40,
                  ),
                  title: const Text('Смотреть на другом устройстве'),
                  subtitle: const Text('Cast и режим приёмника'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.cast),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  key: const Key('settings-logs'),
                  leading: LtToneIcon(
                    icon: Icons.receipt_long_rounded,
                    tone: LtTone(
                      strong: Theme.of(context).colorScheme.onSurfaceVariant,
                      soft: Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                    size: 40,
                  ),
                  title: const Text('Логи'),
                  subtitle: const Text('Что происходило в приложении'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.logs),
                ),
              ],
            ),
          ),
          const LtSectionHeader('Аккаунт'),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  key: const Key('settings-account'),
                  leading: userName == null
                      ? LtToneIcon(
                          icon: Icons.person_outline_rounded,
                          tone: palette.cobalt,
                          size: 40,
                        )
                      : CircleAvatar(
                          backgroundColor: palette.cobalt.soft,
                          foregroundColor: palette.cobalt.strong,
                          child: Text(
                            userName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                  title: Text(userName ?? 'Вы вошли'),
                  subtitle: server.isEmpty ? null : Text('Сервер: $server'),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  key: const Key('settings-sign-out'),
                  leading: LtToneIcon(
                    icon: Icons.logout_rounded,
                    tone: palette.danger,
                    size: 40,
                  ),
                  title: Text(
                    'Выйти из аккаунта',
                    style: TextStyle(color: palette.danger.strong),
                  ),
                  subtitle: const Text('Скачанные видео удалятся с телефона'),
                  onTap: _isSigningOut ? null : _signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await confirmAndSignOut(context, ref);
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }
}
