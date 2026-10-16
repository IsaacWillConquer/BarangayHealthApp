import 'package:flutter/material.dart';

import '../services/survey_repository.dart';
import '../theme.dart';
import '../utils/motion.dart';
import '../widgets/answer_summary.dart';
import '../widgets/common.dart';

/// Read-only view of a survey the resident has already submitted.
///
/// Mirrors the "View" modal in `ResidentSurveys.jsx`. A response is one-shot —
/// `SurveyRepository.activeSurveys` filters out anything already answered — so
/// there is deliberately no editing path here.
class SurveyResponseScreen extends StatefulWidget {
  const SurveyResponseScreen({
    super.key,
    required this.surveys,
    required this.responseId,
    required this.title,
    required this.submittedAt,
  });

  final SurveyRepository surveys;
  final String responseId;
  final String title;
  final String submittedAt;

  @override
  State<SurveyResponseScreen> createState() => _SurveyResponseScreenState();
}

class _SurveyResponseScreenState extends State<SurveyResponseScreen> {
  List<SubmittedAnswer>? _answers;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final answers = await widget.surveys.responseAnswers(widget.responseId);
      if (!mounted) return;
      setState(() {
        _answers = answers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load your response. Check your connection.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : motionEntrance(
              context,
              _error != null
                  ? EmptyState(_error!, icon: Icons.cloud_off_outlined)
                  : _answers!.isEmpty
                  ? const EmptyState('This survey has no recorded answers.')
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            const StatusBadge('Completed'),
                            const Spacer(),
                            Text(
                              'Submitted ${widget.submittedAt.isEmpty ? '—' : widget.submittedAt}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < _answers!.length; i++) ...[
                          AnswerSummaryRow(
                            question: _answers![i].questionText,
                            value: _answers![i].value,
                            leading: '${i + 1}',
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
    );
  }
}
