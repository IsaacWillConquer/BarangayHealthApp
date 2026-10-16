import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kThemeMode = 'theme_mode';

/// Persists the resident's theme choice.
///
/// Kept separate from [ResidentSession] because the theme survives sign-out:
/// a resident who prefers dark mode should not get the light one back after
/// signing out. Uses the same storage the session uses, so no new dependency
/// and no plain-text file on disk.
class ThemePrefs {
  ThemePrefs({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// Reads the stored choice, falling back to following the system.
  Future<ThemeMode> load() async {
    try {
      final raw = await _storage.read(key: _kThemeMode);
      _mode = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      _mode = ThemeMode.system;
    }
    return _mode;
  }

  Future<void> save(ThemeMode mode) async {
    _mode = mode;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    try {
      await _storage.write(key: _kThemeMode, value: value);
    } catch (_) {
      // A failed write only costs the preference on next launch.
    }
  }

  /// system -> light -> dark -> system
  static ThemeMode next(ThemeMode current) => switch (current) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  };
}
