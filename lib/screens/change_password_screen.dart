import 'package:flutter/material.dart';

import '../services/auth_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Forced first-login password change, shown while `MustChangePassword` is true.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    required this.residentId,
    required this.onChanged,
  });

  final String residentId;
  final Future<void> Function() onChanged;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _auth = AuthRepository();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final value = _new.text;
    if (value.length < 7) {
      setState(
        () => _error = 'Your new password must be at least 7 characters.',
      );
      return;
    }
    if (value != _confirm.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await _auth.changePassword(
      residentId: widget.residentId,
      newPassword: value,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      setState(() => _error = result.error);
      return;
    }
    await widget.onChanged();

    // When this screen is pushed onto a route, return to the caller so it can
    // continue the flow. `RootScreen` renders it as the home route instead.
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set your password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.warningBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colors.warningBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: context.colors.warningFg,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your account still uses the temporary password issued with your Resident Number. '
                          'Choose a new one to continue.',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.warningFg,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.colors.errorBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.colors.errorBorder),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.errorFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const FieldLabel('New password'),
                TextField(
                  controller: _new,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: 'At least 7 characters',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      color: context.colors.textMuted,
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const FieldLabel('Confirm new password'),
                TextField(
                  controller: _confirm,
                  obscureText: _obscure,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'Re-enter your new password',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
