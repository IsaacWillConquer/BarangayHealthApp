import 'package:flutter/material.dart';

import '../theme.dart';

/// One question with the answer the resident picked.
///
/// Shared by the pre-submit review sheet and the read-only response screen so
/// the two can never disagree about how an answer reads.
class AnswerSummaryRow extends StatelessWidget {
  const AnswerSummaryRow({
    super.key,
    required this.question,
    required this.value,
    this.leading,
  });

  final String question;

  /// The answer text. A blank value renders as a muted "Not answered" rather
  /// than disappearing, so a skipped optional question is visible as a choice
  /// the resident made instead of an oversight.
  final String value;

  /// Optional question number, rendered before the question text.
  final String? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final blank = value.trim().isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                Text(
                  '$leading.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // A 1000-character essay answer wraps across many lines, so this has
          // to be free to grow rather than being capped.
          Text(
            blank ? 'Not answered' : value,
            style: TextStyle(
              fontSize: 14,
              color: blank ? colors.textMuted : colors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
