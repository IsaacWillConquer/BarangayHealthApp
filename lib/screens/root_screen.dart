import 'package:flutter/material.dart';

import '../services/auth_repository.dart';
import '../services/resident_session.dart';
import '../theme.dart';
import '../utils/motion.dart';
import '../widgets/common.dart' show showFlash;
import 'app_shell.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Chooses the first screen: login, forced password change, or the app shell.
class RootScreen extends StatefulWidget {
  const RootScreen({
    super.key,
    this.onThemeModeChanged,
    this.themeMode = _systemTheme,
  });

  static ThemeMode _systemTheme() => ThemeMode.system;

  /// Set by the app root so the Profile toggle can change the app theme.
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  /// Reports the app's current theme choice for the Profile toggle's icon.
  final ThemeMode Function() themeMode;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final _session = ResidentSession();
  final _auth = AuthRepository();

  bool _booting = true;
  bool _mustChangePassword = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final restored = await _session.restore();

    // The shared project already contains RES-0001, so make sure the counter
    // starts past it and the first mobile registration lands on RES-0002.
    await _auth.ensureCounterAtLeast(1);

    if (restored) {
      final data = (await _session.fetchSelf())?.data();
      final stillValid =
          data != null &&
          data['Status'] == 'Active' &&
          data['IsArchived'] != true;
      if (stillValid && data['MustChangePassword'] == true) {
        if (mounted) setState(() => _mustChangePassword = true);
      } else if (!stillValid) {
        await _session.signOut();
      }
    }

    if (mounted) setState(() => _booting = false);
  }

  Future<void> _handleAuthenticated(String residentId, String firstName) async {
    await _session.signIn(
      residentId: residentId,
      role: 'Resident',
      firstName: firstName,
    );
    if (!mounted) return;
    setState(() => _mustChangePassword = false);
  }

  Future<void> _handleSignOut() async {
    await _session.signOut();
    if (!mounted) return;
    setState(() => _mustChangePassword = false);
  }

  Future<void> _openRegister() async {
    final created = await Navigator.of(context).push<bool>(
      FadeThroughRoute(
        animate: !reducedMotion(context),
        builder: (_) => const RegisterScreen(),
      ),
    );
    if (created == true && mounted) {
      showFlash(
        context,
        'Registration submitted. It needs staff approval before you can log in.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: context.colors.accent),
        ),
      );
    }

    if (_mustChangePassword) {
      return ChangePasswordScreen(
        residentId: _session.residentId!,
        onChanged: () async => setState(() => _mustChangePassword = false),
      );
    }

    if (_session.isSignedIn) {
      return AppShell(
        session: _session,
        onSignOut: _handleSignOut,
        onThemeModeChanged: widget.onThemeModeChanged,
        themeMode: widget.themeMode,
      );
    }

    return LoginScreen(
      auth: _auth,
      onAuthenticated: _handleAuthenticated,
      onRegister: () => _openRegister(),
    );
  }
}
