import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/bootstrap_providers.dart';

/// Light, dark or as the phone is set. Kept on the device; the phone's own
/// setting is the default.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._ref) : super(ThemeMode.system) {
    _load();
  }

  final Ref _ref;

  static const String _storageKey = 'ui_theme_mode';

  Future<void> _load() async {
    try {
      final String? saved =
          await _ref.read(secureStorageServiceProvider).read(_storageKey);
      final ThemeMode? mode = _parse(saved);
      if (mode != null && mounted) {
        state = mode;
      }
    } catch (_) {
      // No storage (tests, a first start): the phone's setting applies.
    }
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    try {
      await _ref.read(secureStorageServiceProvider).write(_storageKey, mode.name);
    } catch (_) {
      // Not saved: the choice still holds until the app is closed.
    }
  }

  static ThemeMode? _parse(String? value) {
    for (final ThemeMode mode in ThemeMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return null;
  }
}

final StateNotifierProvider<ThemeModeController, ThemeMode> themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (Ref ref) => ThemeModeController(ref),
);
