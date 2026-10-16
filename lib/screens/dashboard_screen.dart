import 'package:flutter/material.dart';

import '../services/profile_repository.dart';
import '../services/resident_session.dart';
import '../services/survey_repository.dart';
import '../theme.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';

/// Resident home. Mirrors `src/pages/resident/ResidentDashboard.jsx`, reduced to
/// the fields a resident can act on.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.session,
    required this.profile,
    required this.surveys,
  });

  final ResidentSession session;
  final ProfileRepository profile;
  final SurveyRepository surveys;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _openSurveys = 0;
  int _completedSurveys = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.profile.refresh();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final open = await widget.surveys.activeSurveys();
      final done = await widget.surveys.completedSurveys();
      if (!mounted) return;
      setState(() {
        _openSurveys = open.length;
        _completedSurveys = done.length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile.cached;
    final firstName = (profile?['FirstName'] as String?)?.trim();
    final displayName = (firstName == null || firstName.isEmpty)
        ? 'Resident'
        : firstName;
    final residentNumber = (profile?['ResidentNumber'] as String?) ?? '—';
    final status = (profile?['Status'] as String?) ?? 'Unknown';
    final age = ageFromBirthday(profile?['Birthday'] as String?);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barangay Health'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                residentNumber,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.profile.refresh();
          await _loadCounts();
        },
        color: context.colors.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Hello, $displayName',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome to your resident portal.',
              style: TextStyle(fontSize: 14, color: context.colors.textMuted),
            ),
            const SizedBox(height: 20),

            SectionCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account status',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textMuted,
                          ),
                        ),
                        SizedBox(height: 6),
                        StatusBadge(status),
                        SizedBox(height: 10),
                        Text(
                          residentNumber,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (age != null)
                    Column(
                      children: [
                        Text(
                          'Age',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$age',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: context.colors.accentText,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Surveys to answer',
                    value: _loading ? '—' : '$_openSurveys',
                    icon: Icons.assignment_outlined,
                    onTap: () =>
                        showFlash(context, 'Open the Surveys tab to answer.'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Completed',
                    value: _loading ? '—' : '$_completedSurveys',
                    icon: Icons.check_circle_outline,
                    onTap: () =>
                        showFlash(context, 'Open the Surveys tab to review.'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            SectionCard(
              title: 'Your details',
              trailing: TextButton(
                onPressed: () => showFlash(
                  context,
                  'Use the Profile tab to update your details.',
                ),
                child: Text(
                  'Edit',
                  style: TextStyle(color: context.colors.accent),
                ),
              ),
              child: Column(
                children: [
                  InfoRow('Full name', _fullName(profile)),
                  InfoRow('Birthday', (profile?['Birthday'] as String?) ?? ''),
                  InfoRow('Gender', (profile?['Gender'] as String?) ?? ''),
                  InfoRow(
                    'Civil status',
                    (profile?['CivilStatus'] as String?) ?? '',
                  ),
                  InfoRow(
                    'Contact number',
                    (profile?['ContactNumber'] as String?) ?? '',
                  ),
                  InfoRow('Address', (profile?['Address'] as String?) ?? ''),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static String _fullName(Map<String, dynamic>? p) {
    if (p == null) return '';
    return [
      p['FirstName'],
      p['MiddleName'],
      p['LastName'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: context.colors.accent),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
