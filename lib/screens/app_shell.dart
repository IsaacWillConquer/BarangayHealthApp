import 'dart:async';

import 'package:flutter/material.dart';

import '../services/profile_repository.dart';
import '../services/resident_session.dart';
import '../services/survey_repository.dart';
import '../theme.dart';
import '../utils/motion.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'surveys_screen.dart';

ThemeMode _systemThemeMode() => ThemeMode.system;

/// Signed-in container: bottom navigation plus the shared repositories.
///
/// The repositories are created once here so the profile live listener keeps
/// running across dashboard and profile tab switches.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.session,
    required this.onSignOut,
    this.onThemeModeChanged,
    this.themeMode = _systemThemeMode,
  });

  final ResidentSession session;
  final Future<void> Function() onSignOut;

  /// Forwarded to the Profile screen's theme toggle. Null disables the toggle.
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  final ThemeMode Function() themeMode;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final ProfileRepository _profile;
  late final SurveyRepository _surveys;

  /// Fades and lifts the tab that just became visible.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: kFadeDuration,
  );
  late final Animation<double> _tabOpacity = CurvedAnimation(
    parent: _tabFade,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _tabRise = Tween<Offset>(
    begin: const Offset(0, 0.02),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _tabFade, curve: Curves.easeOut));

  StreamSubscription<Map<String, dynamic>>? _profileSub;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _profile = ProfileRepository(residentId: widget.session.residentId!);
    _surveys = SurveyRepository(residentId: widget.session.residentId!);

    // One shared subscription feeds both the dashboard's cached profile and
    // the profile tab, so switching tabs does not re-open a Firestore stream.
    _profileSub = _profile.watch().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) return;
    _entered = true;
    // Reads the platform's reduced-motion setting, so this waits until the
    // MediaQuery is actually available.
    _playTabEntrance();
  }

  void _playTabEntrance() {
    if (reducedMotion(context)) {
      _tabFade.value = 1;
    } else {
      _tabFade.forward(from: 0);
    }
  }

  void _selectTab(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _playTabEntrance();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _tabFade.dispose();
    super.dispose();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need your Resident Number and password to sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        session: widget.session,
        profile: _profile,
        surveys: _surveys,
      ),
      SurveysScreen(profile: _profile, surveys: _surveys),
      ProfileScreen(
        session: widget.session,
        profile: _profile,
        onSignOut: _confirmSignOut,
        onThemeModeChanged: widget.onThemeModeChanged,
        themeMode: widget.themeMode,
      ),
    ];

    return Scaffold(
      body: FadeTransition(
        opacity: _tabOpacity,
        // IndexedStack keeps every tab mounted, so switching tabs never drops
        // scroll position and never re-opens the Firestore stream. A plain
        // AnimatedSwitcher would animate the swap more directly but would
        // dispose the outgoing tab's State, costing a re-subscribe per tap.
        child: SlideTransition(
          position: _tabRise,
          child: IndexedStack(index: _index, children: pages),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Surveys',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
