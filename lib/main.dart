import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/root_screen.dart';
import 'services/theme_prefs.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await AppFirebase.init();

  // Read the saved theme before the first frame so the app never paints in
  // light mode and then snaps to dark a moment later.
  final themePrefs = ThemePrefs();
  await themePrefs.load();

  runApp(BarangayHealthApp(themePrefs: themePrefs));
}

class BarangayHealthApp extends StatefulWidget {
  const BarangayHealthApp({super.key, required this.themePrefs});

  final ThemePrefs themePrefs;

  @override
  State<BarangayHealthApp> createState() => _BarangayHealthAppState();
}

class _BarangayHealthAppState extends State<BarangayHealthApp> {
  late ThemeMode _themeMode = widget.themePrefs.mode;

  Future<void> _setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    setState(() => _themeMode = mode);
    await widget.themePrefs.save(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barangay Health',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      darkTheme: AppTheme.build(brightness: Brightness.dark),
      themeMode: _themeMode,
      home: RootScreen(
        onThemeModeChanged: _setThemeMode,
        themeMode: () => _themeMode,
      ),
    );
  }
}
