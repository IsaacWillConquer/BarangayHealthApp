import 'package:flutter/material.dart';

import '../services/profile_repository.dart';
import '../services/survey_repository.dart';
import '../theme.dart';
import '../utils/motion.dart';
import '../widgets/common.dart';
import 'survey_detail_screen.dart';
import 'survey_response_screen.dart';

/// Open and completed surveys, mirroring `src/pages/resident/ResidentSurveys.jsx`.
class SurveysScreen extends StatefulWidget {
  const SurveysScreen({
    super.key,
    required this.profile,
    required this.surveys,
  });

  final ProfileRepository profile;
  final SurveyRepository surveys;

  @override
  State<SurveysScreen> createState() => _SurveysScreenState();
}

class _SurveysScreenState extends State<SurveysScreen> {
  bool _loading = true;
  String? _error;
  List<QuerySurvey> _open = [];
  List<CompletedSurvey> _done = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final open = await widget.surveys.activeSurveys();
      final done = await widget.surveys.completedSurveys();
      if (!mounted) return;
      setState(() {
        _open = open
            .map(
              (d) => QuerySurvey(
                id: d.id,
                title: (d.get('Title') as String?) ?? '(untitled survey)',
                description: (d.get('Description') as String?) ?? '',
                closeAt: d.get('CloseAt') as String?,
              ),
            )
            .toList();
        _done = done.map(CompletedSurvey.fromRow).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load surveys. Check your connection.";
        _loading = false;
      });
    }
  }

  Future<void> _openSurvey(QuerySurvey survey) async {
    final submitted = await Navigator.of(context).push<bool>(
      FadeThroughRoute(
        animate: !reducedMotion(context),
        builder: (_) =>
            SurveyDetailScreen(surveys: widget.surveys, survey: survey),
      ),
    );
    if (submitted == true) _load();
  }

  /// Opens a completed response for reading. Nothing can change from here, so
  /// there is nothing to refresh on the way back.
  Future<void> _openResponse(CompletedSurvey completed) async {
    await Navigator.of(context).push(
      FadeThroughRoute(
        animate: !reducedMotion(context),
        builder: (_) => SurveyResponseScreen(
          surveys: widget.surveys,
          responseId: completed.responseId,
          title: completed.title,
          submittedAt: completed.submittedAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Surveys')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: context.colors.accent,
        child: _loading
            ? Center(
                child: CircularProgressIndicator(color: context.colors.accent),
              )
            // Fades the results in as they replace the spinner, so the list
            // never pops into place.
            : motionEntrance(
                context,
                _error != null
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          EmptyState(_error!, icon: Icons.cloud_off_outlined),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SectionHeader('Open surveys'),
                          if (_open.isEmpty)
                            const Card(
                              child: EmptyState(
                                'No surveys need your answer right now.',
                                icon: Icons.task_alt,
                              ),
                            )
                          else
                            for (final s in _open)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _SurveyCard(
                                  title: s.title,
                                  subtitle: s.closeAt == null
                                      ? s.description
                                      : 'Closes ${s.closeAt} — ${s.description}',
                                  onTap: () => _openSurvey(s),
                                ),
                              ),
                          const SizedBox(height: 28),
                          const SectionHeader('Completed'),
                          if (_done.isEmpty)
                            const Card(
                              child: EmptyState(
                                'You have not submitted any surveys yet.',
                                icon: Icons.inbox_outlined,
                              ),
                            )
                          else
                            for (final s in _done)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CompletedCard(
                                  title: s.title,
                                  submittedAt: s.submittedAt,
                                  onTap: () => _openResponse(s),
                                ),
                              ),
                          const SizedBox(height: 24),
                        ],
                      ),
              ),
      ),
    );
  }
}

class QuerySurvey {
  const QuerySurvey({
    required this.id,
    required this.title,
    required this.description,
    required this.closeAt,
  });

  final String id;
  final String title;
  final String description;
  final String? closeAt;
}

class CompletedSurvey {
  const CompletedSurvey({
    required this.surveyId,
    required this.responseId,
    required this.title,
    required this.submittedAt,
  });

  factory CompletedSurvey.fromRow(Map<String, dynamic> row) => CompletedSurvey(
    surveyId: (row['SurveyID'] as String?) ?? '',
    responseId: (row['ResponseID'] as String?) ?? '',
    title: (row['Title'] as String?) ?? '(deleted survey)',
    submittedAt: (row['SubmittedAt'] as String?) ?? '',
  );

  final String surveyId;
  final String responseId;
  final String title;
  final String submittedAt;
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({
    required this.title,
    required this.submittedAt,
    required this.onTap,
  });

  final String title;
  final String submittedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted ${submittedAt.isEmpty ? '—' : submittedAt}',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const StatusBadge('Completed'),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurveyCard extends StatelessWidget {
  const _SurveyCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
