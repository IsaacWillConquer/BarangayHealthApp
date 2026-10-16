import 'package:flutter/material.dart';

import '../services/auth_repository.dart';
import '../theme.dart';
import '../utils/motion.dart';
import '../widgets/common.dart';
import 'change_password_screen.dart';

/// Resident login, mirroring `src/pages/auth/Login.jsx`.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.auth,
    required this.onAuthenticated,
    required this.onRegister,
  });

  final AuthRepository auth;
  final Future<void> Function(String residentId, String firstName)
  onAuthenticated;
  final VoidCallback onRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await widget.auth.login(
      identifier: _identifier.text,
      password: _password.text,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      setState(() => _error = result.error);
      return;
    }

    // Re-read the document so the session stores its real id and first name.
    final doc = await widget.auth.docForLogin(_identifier.text.trim());
    if (!mounted) return;
    if (doc == null) {
      setState(() => _error = 'Could not load your account. Please try again.');
      return;
    }

    if (result.mustChangePassword) {
      final changed = await Navigator.of(context).push<bool>(
        FadeThroughRoute(
          animate: !reducedMotion(context),
          builder: (_) => ChangePasswordScreen(
            residentId: doc['ResidentID'] as String,
            onChanged: () async {},
          ),
        ),
      );
      if (changed != true) return;
    }

    await widget.onAuthenticated(
      doc['ResidentID'] as String,
      (doc['FirstName'] as String?) ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: 28),
                    if (_error != null) ...[
                      _ErrorBanner(_error!),
                      const SizedBox(height: 16),
                    ],
                    const FieldLabel('Resident Number or Email'),
                    TextFormField(
                      controller: _identifier,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(hintText: 'RES-0001'),
                    ),
                    const SizedBox(height: 16),
                    const FieldLabel('Password'),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
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
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onRegister,
                          child: Text(
                            'Register',
                            style: TextStyle(
                              color: context.colors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: context.colors.appBarBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.health_and_safety_outlined,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Barangay Health',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Resident Portal',
          style: TextStyle(fontSize: 14, color: context.colors.textMuted),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.errorBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.errorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: context.colors.errorFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.errorFg,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
