import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/auth_error_messages.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';

enum AuthMode { signIn, register }

/// Sign-in and registration in one screen. On success it does NOT navigate;
/// AuthGate reacts to the auth-state stream and shows the profile.
class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  bool _busy = false;
  String? _error;

  bool get _isRegister => _mode == AuthMode.register;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _mode = _isRegister ? AuthMode.signIn : AuthMode.register;
      _error = null;
      _passwordController.clear();
      _confirmController.clear();
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (_busy) return; // block duplicate submissions
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final registering = _isRegister;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (registering) {
        await widget.authService.register(email, password);
        messenger.showSnackBar(
          const SnackBar(content: Text('Account created. You are now signed in.')),
        );
      } else {
        await widget.authService.signIn(email, password);
        messenger.showSnackBar(
          const SnackBar(content: Text('Signed in successfully.')),
        );
      }
      // AuthGate swaps this screen for ProfileScreen via authStateChanges.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(
          e,
          registering ? AuthAction.register : AuthAction.signIn,
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailError = validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() => _error = 'Enter your account email above, then tap "Forgot password?" again.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    // Same message whether or not the account exists (privacy-aware).
    const generic = 'If an account exists for that email, a reset link is on its way.';
    try {
      await widget.authService.sendPasswordResetEmail(_emailController.text);
      messenger.showSnackBar(const SnackBar(content: Text(generic)));
    } catch (e) {
      final message = authErrorMessage(e, AuthAction.passwordReset);
      if (message == generic) {
        messenger.showSnackBar(const SnackBar(content: Text(generic)));
      } else if (mounted) {
        setState(() => _error = message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          _isRegister ? Icons.person_add_alt_1 : Icons.lock_open_rounded,
                          size: 34,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isRegister ? 'Create your account' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isRegister
                            ? 'Register with your email and a password (6+ characters).'
                            : 'Sign in to open your profile.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        key: const Key('emailField'),
                        controller: _emailController,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: validateEmail,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      PasswordField(
                        key: const Key('passwordField'),
                        controller: _passwordController,
                        label: 'Password',
                        enabled: !_busy,
                        validator: validatePassword,
                        autofillHints: [
                          _isRegister ? AutofillHints.newPassword : AutofillHints.password,
                        ],
                        textInputAction: _isRegister ? TextInputAction.next : TextInputAction.done,
                        onFieldSubmitted: _isRegister ? null : (_) => _submit(),
                      ),
                      if (_isRegister) ...[
                        const SizedBox(height: 14),
                        PasswordField(
                          key: const Key('confirmField'),
                          controller: _confirmController,
                          label: 'Confirm password',
                          enabled: !_busy,
                          validator: (v) => validateConfirmPassword(v, _passwordController.text),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                      if (!_isRegister)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : _forgotPassword,
                            child: const Text('Forgot password?'),
                          ),
                        )
                      else
                        const SizedBox(height: 16),
                      if (_error != null) ...[
                        ErrorBanner(message: _error!),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        key: const Key('submitButton'),
                        onPressed: _busy ? null : _submit,
                        child: BusyLabel(
                          busy: _busy,
                          label: _isRegister ? 'Create account' : 'Sign in',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _busy ? null : _toggleMode,
                        child: Text(
                          _isRegister
                              ? 'Already have an account? Sign in'
                              : 'New here? Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
