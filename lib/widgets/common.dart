import 'package:flutter/material.dart';

import '../services/profile_image.dart';
import '../theme.dart';

/// Reusable form pieces styled to match the web portal's inputs and buttons.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          if (optional)
            Text(
              '  (optional)',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Plain section heading for stacked forms.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.headingFont,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

/// A card section with a heading, matching the portal's white panels.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontFamily: AppTheme.headingFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Inline status pill, mirroring `src/components/ui/StatusBadge.jsx`.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    late final Color bg;
    late final Color fg;
    switch (status) {
      case 'Active':
      case 'Approved':
        bg = colors.successBg;
        fg = colors.successFg;
      case 'Pending':
      case 'Upcoming':
        bg = colors.warningBg;
        fg = colors.warningFg;
      case 'Rejected':
      case 'Closed':
        bg = colors.errorBg;
        fg = colors.errorFg;
      default:
        bg = colors.neutralBg;
        fg = colors.neutralFg;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Read-only label/value row used across profile and dashboard views.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final empty = value.isEmpty || value == 'null';
    final labelWidget = Text(
      label,
      style: TextStyle(fontSize: 13, color: colors.textSecondary),
    );
    final valueWidget = Text(
      empty ? '—' : value,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: empty ? colors.textMuted : colors.textPrimary,
      ),
    );

    // Labels and values sit side by side when there is room for them. On a
    // narrow phone a fixed label column would starve the value, and long
    // addresses and Filipino names would then wrap into a tall ragged block,
    // so the pair stacks instead.
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 340;
        final content = stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [labelWidget, const SizedBox(height: 2), valueWidget],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 132, child: labelWidget),
                  Expanded(child: valueWidget),
                ],
              );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          // Sibling rows have to share a left edge. A parent `Column` centres
          // its children by default, so without stretching, each row gets
          // nudged by its own intrinsic width and the labels come out ragged.
          // Only stretch when the width is bounded; an unbounded parent (a
          // `Row`) still needs the intrinsic size.
          child: constraints.maxWidth.isFinite
              ? SizedBox(width: double.infinity, child: content)
              : content,
        );
      },
    );
  }
}

/// Round resident photo that degrades to initials.
///
/// The stored value is a base64 data URL written by either client, but an
/// `http(s)` value is also accepted so a Cloud Storage migration would not
/// need a second avatar. Anything undecodable falls back to the initials block
/// rather than showing a broken image, which matters because the value is
/// attacker-influenced in the sense that staff can edit the resident document.
class ResidentAvatar extends StatelessWidget {
  const ResidentAvatar({
    super.key,
    required this.initials,
    required this.photo,
    this.size = 54,
  });

  final String initials;

  /// The raw `ProfileImagePath` value, if any.
  final String? photo;

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = photo?.trim();
    final hasPhoto = value != null && value.isNotEmpty;
    final remote = isRemoteProfilePhoto(value);

    Widget child;
    if (!hasPhoto) {
      child = _initialsBlock(context);
    } else if (remote) {
      child = Image.network(
        value,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initialsBlock(context),
      );
    } else {
      final bytes = decodeProfilePhoto(value);
      child = bytes == null
          ? _initialsBlock(context)
          : Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _initialsBlock(context),
            );
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.appBarBg),
          child: child,
        ),
      ),
    );
  }

  Widget _initialsBlock(BuildContext context) => Center(
    child: Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.33,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Avatar plus gallery actions for setting or clearing the resident photo.
///
/// Shared by registration and edit profile so the hint text and the accepted
/// formats stay identical to the web portal's upload dialog.
class ProfilePhotoField extends StatelessWidget {
  const ProfilePhotoField({
    super.key,
    required this.initials,
    required this.photo,
    required this.onPick,
    this.onRemove,
    this.busy = false,
  });

  final String initials;

  /// The pending or stored data URL.
  final String? photo;

  final VoidCallback onPick;

  /// Omitted entirely when there is nothing to remove.
  final VoidCallback? onRemove;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo != null && photo!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ResidentAvatar(initials: initials, photo: photo, size: 84),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : onPick,
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: Text(hasPhoto ? 'Change photo' : 'Add photo'),
        ),
        if (hasPhoto && onRemove != null)
          TextButton(
            onPressed: busy ? null : onRemove,
            child: const Text('Remove photo'),
          ),
        const SizedBox(height: 6),
        Text(
          'JPG or PNG, under 3MB.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: context.colors.textMuted),
        ),
      ],
    );
  }
}

/// Empty-state block for lists with no records.
class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: colors.border),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

void showFlash(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? context.colors.errorFg
            : context.colors.flashBg,
        duration: const Duration(seconds: 3),
      ),
    );
}
