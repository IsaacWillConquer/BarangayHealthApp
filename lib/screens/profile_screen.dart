import 'package:flutter/material.dart';

import '../services/profile_image.dart';
import '../services/profile_repository.dart';
import '../services/resident_session.dart';
import '../services/theme_prefs.dart';
import '../theme.dart';
import '../utils/motion.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';
import 'edit_profile_screen.dart';

/// Default for [ProfileScreen.themeMode] when no app-level state is supplied.
ThemeMode _defaultThemeMode() => ThemeMode.system;

/// Read-only profile view, mirroring `src/pages/resident/Profile.jsx`.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.session,
    required this.profile,
    required this.onSignOut,
    this.onThemeModeChanged,
    this.themeMode = _defaultThemeMode,
  });

  final ResidentSession session;
  final ProfileRepository profile;
  final Future<void> Function() onSignOut;

  /// Enables the theme toggle when the app root provides it.
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  /// The app's current choice, needed because the resolved brightness cannot
  /// distinguish an explicit dark from a system that happens to be dark.
  final ThemeMode Function() themeMode;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Read straight from the repository so the app shell's shared subscription
  /// keeps this screen current without a second Firestore stream.
  Map<String, dynamic>? get _data => widget.profile.cached;

  @override
  void initState() {
    super.initState();
    widget.profile.refresh();
  }

  String _s(String key) => (_data?[key] as String?) ?? '';
  String? _opt(String key) {
    final v = _data?[key] as String?;
    return (v == null || v.isEmpty) ? null : v;
  }

  Map<String, dynamic>? get _spouse {
    final spouse = _data?['Spouse'];
    return spouse is Map ? spouse.cast<String, dynamic>() : null;
  }

  static IconData _themeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.brightness_auto,
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
    };
  }

  static String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'follows system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      FadeThroughRoute(
        animate: !reducedMotion(context),
        builder: (_) => EditProfileScreen(
          profile: widget.profile,
          current: _data ?? const {},
        ),
      ),
    );
    if (saved == true && mounted) {
      showFlash(context, 'Profile updated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final age = ageFromBirthday(_opt('Birthday'));

    return Scaffold(
      appBar: AppBar(
        title: Text('My profile'),
        actions: [
          if (widget.onThemeModeChanged != null)
            IconButton(
              icon: Icon(_themeIcon(widget.themeMode()), size: 20),
              tooltip: 'Theme: ${_themeLabel(widget.themeMode())}',
              onPressed: () => widget.onThemeModeChanged!(
                ThemePrefs.next(widget.themeMode()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign out',
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      body: data == null
          ? Center(
              child: CircularProgressIndicator(color: context.colors.accent),
            )
          : RefreshIndicator(
              onRefresh: widget.profile.refresh,
              color: context.colors.accent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          ResidentAvatar(
                            initials: _initials(),
                            photo: _opt(kProfilePhotoField),
                            size: 54,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fullName(),
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    StatusBadge(_opt('Status') ?? 'Unknown'),
                                    const SizedBox(width: 8),
                                    Text(
                                      _opt('ResidentNumber') ?? '—',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: context.colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  FilledButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit profile'),
                  ),
                  const SizedBox(height: 20),

                  const SectionHeader('Personal'),
                  SectionCard(
                    child: Column(
                      children: [
                        InfoRow('First name', _s('FirstName')),
                        InfoRow('Middle name', _s('MiddleName')),
                        InfoRow('Last name', _s('LastName')),
                        InfoRow('Suffix', _s('ExtensionName')),
                        InfoRow('Birthday', _opt('Birthday') ?? ''),
                        InfoRow('Age', age == null ? '' : '$age'),
                        InfoRow('Gender', _opt('Gender') ?? ''),
                        InfoRow('Civil status', _opt('CivilStatus') ?? ''),
                      ],
                    ),
                  ),

                  if (_spouse != null) ...[
                    const SizedBox(height: 24),
                    const SectionHeader('Spouse'),
                    SectionCard(
                      child: Column(
                        children: [
                          InfoRow('Name', _spouse!['Name'] as String? ?? ''),
                          InfoRow(
                            'Birthday',
                            _spouse!['Birthdate'] as String? ?? '',
                          ),
                          InfoRow(
                            'Civil status',
                            _spouse!['CivilStatus'] as String? ?? '',
                          ),
                          InfoRow(
                            'Status',
                            _spouse!['Status'] as String? ?? '',
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const SectionHeader('Contact'),
                  SectionCard(
                    child: Column(
                      children: [
                        InfoRow('Email', _opt('Email') ?? ''),
                        InfoRow('Contact number', _opt('ContactNumber') ?? ''),
                        InfoRow('Home phone', _opt('HomePhone') ?? ''),
                        InfoRow('Address', _opt('Address') ?? ''),
                        InfoRow('Address line 2', _opt('Address2') ?? ''),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const SectionHeader('Emergency contact'),
                  SectionCard(
                    child: Column(
                      children: [
                        InfoRow('Name', _opt('EmergencyContactName') ?? ''),
                        InfoRow(
                          'Relationship',
                          _opt('EmergencyContactRelationship') ?? '',
                        ),
                        InfoRow(
                          'Contact number',
                          _opt('EmergencyContactNumber') ?? '',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const SectionHeader('Household'),
                  SectionCard(
                    child: Column(
                      children: [
                        InfoRow('Father', _opt('FatherName') ?? ''),
                        InfoRow('Mother', _opt('MotherName') ?? ''),
                        InfoRow(
                          'Reference 1',
                          _reference(
                            _opt('Reference1Name'),
                            _opt('Reference1Contact'),
                          ),
                        ),
                        InfoRow(
                          'Reference 2',
                          _reference(
                            _opt('Reference2Name'),
                            _opt('Reference2Contact'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const SectionHeader('Work'),
                  SectionCard(
                    child: Column(
                      children: [
                        InfoRow('Occupation', _opt('Occupation') ?? ''),
                        InfoRow(
                          'Employer / school',
                          _opt('OccupationLocation') ?? '',
                        ),
                        InfoRow('About', _opt('Bio') ?? ''),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  static String _reference(String? name, String? contact) {
    if ((name ?? '').isEmpty && (contact ?? '').isEmpty) return '';
    return '${name ?? ''}${contact == null || contact.isEmpty ? '' : '  ·  $contact'}';
  }

  String _fullName() => [
    _s('FirstName'),
    _s('MiddleName'),
    _s('LastName'),
    _s('ExtensionName'),
  ].where((s) => s.isNotEmpty).join(' ');

  String _initials() {
    final first = _s('FirstName');
    final last = _s('LastName');
    return '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}'
        .toUpperCase();
  }
}
