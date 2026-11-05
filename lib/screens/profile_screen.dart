import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/auth_error_messages.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';

/// Protected screen. AuthGate only builds it while a user is signed in.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _updatingPassword = false;
  bool _signingOut = false;
  String? _passwordError;
  String? _passwordSuccess;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _signingOut = true);
    try {
      await widget.authService.signOut();
      messenger.showSnackBar(const SnackBar(content: Text('You have been signed out.')));
      // AuthGate replaces this screen with the sign-in screen.
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(authErrorMessage(e, AuthAction.signOut))),
      );
      setState(() => _signingOut = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_updatingPassword) return;
    FocusScope.of(context).unfocus();
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

    final newPassword = _newPasswordController.text;
    setState(() {
      _updatingPassword = true;
      _passwordError = null;
      _passwordSuccess = null;
    });

    try {
      await widget.authService.changePassword(newPassword);
      _onPasswordUpdated();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Sensitive action on an old session: confirm identity, then retry.
        await _reauthenticateAndRetry(newPassword);
      } else if (mounted) {
        setState(() => _passwordError = authErrorMessage(e, AuthAction.updatePassword));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _passwordError = authErrorMessage(e, AuthAction.updatePassword));
      }
    } finally {
      if (mounted) setState(() => _updatingPassword = false);
    }
  }

  Future<void> _reauthenticateAndRetry(String newPassword) async {
    final user = widget.authService.currentUser;
    if (user == null || (user.email ?? '').isEmpty) {
      if (mounted) {
        setState(() => _passwordError = 'Your session has ended. Please sign in again.');
      }
      return;
    }

    // Keep asking until the user confirms correctly or cancels.
    String? dialogError;
    while (true) {
      if (!mounted) return;
      final currentPassword = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReauthDialog(email: user.email!, errorText: dialogError),
      );

      if (currentPassword == null) {
        // Cancelled re-authentication.
        if (mounted) {
          setState(() => _passwordError =
              'Password not changed. Confirm your current password to finish the update.');
        }
        return;
      }

      try {
        await widget.authService.reauthenticateAndChangePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        _onPasswordUpdated(afterReauth: true);
        return;
      } on FirebaseAuthException catch (e) {
        final action = _isCredentialError(e.code)
            ? AuthAction.reauthenticate
            : AuthAction.updatePassword;
        final message = authErrorMessage(e, action);
        if (_isCredentialError(e.code)) {
          dialogError = message; // show inside the dialog and let them retry
          continue;
        }
        if (mounted) setState(() => _passwordError = message);
        return;
      } catch (e) {
        if (mounted) {
          setState(() => _passwordError = authErrorMessage(e, AuthAction.reauthenticate));
        }
        return;
      }
    }
  }

  bool _isCredentialError(String code) =>
      code == 'wrong-password' ||
      code == 'invalid-credential' ||
      code == 'INVALID_LOGIN_CREDENTIALS' ||
      code == 'user-mismatch';

  void _onPasswordUpdated({bool afterReauth = false}) {
    if (!mounted) return;
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _passwordFormKey.currentState?.reset();
    setState(() {
      _passwordSuccess = afterReauth
          ? 'Identity confirmed and password updated. Use your new password next time you sign in.'
          : 'Password updated. Use your new password next time you sign in.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated successfully.')),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Unknown';
    final local = value.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour < 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} · $hour12:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = widget.authService.currentUser;
    final email = user?.email ?? 'Unknown email';
    final busy = _updatingPassword || _signingOut;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: busy ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ----- Signed-in identity -----
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: scheme.primary,
                            child: Text(
                              email.isNotEmpty ? email[0].toUpperCase() : '?',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text('Signed in as', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          SelectableText(
                            email,
                            key: const Key('profileEmail'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Chip(
                            avatar: Icon(Icons.verified_user_outlined, size: 18, color: scheme.primary),
                            label: const Text('Protected · signed-in only'),
                          ),
                          const Divider(height: 28),
                          _InfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Account created',
                            value: _formatDate(user?.metadata.creationTime),
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.login,
                            label: 'Last sign-in',
                            value: _formatDate(user?.metadata.lastSignInTime),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ----- Change password -----
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _passwordFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Change password',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              'At least 6 characters. If your sign-in is old, we\'ll ask for your current password first.',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 16),
                            PasswordField(
                              key: const Key('newPasswordField'),
                              controller: _newPasswordController,
                              label: 'New password',
                              enabled: !busy,
                              validator: validatePassword,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: 12),
                            PasswordField(
                              key: const Key('confirmNewPasswordField'),
                              controller: _confirmPasswordController,
                              label: 'Confirm new password',
                              enabled: !busy,
                              validator: (v) => validateConfirmPassword(v, _newPasswordController.text),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _updatePassword(),
                            ),
                            const SizedBox(height: 16),
                            if (_passwordError != null) ...[
                              ErrorBanner(message: _passwordError!),
                              const SizedBox(height: 12),
                            ],
                            if (_passwordSuccess != null) ...[
                              _SuccessBanner(message: _passwordSuccess!),
                              const SizedBox(height: 12),
                            ],
                            FilledButton.tonal(
                              key: const Key('updatePasswordButton'),
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                              onPressed: busy ? null : _updatePassword,
                              child: BusyLabel(busy: _updatingPassword, label: 'Update password'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ----- Sign out -----
                  OutlinedButton.icon(
                    key: const Key('signOutButton'),
                    onPressed: busy ? null : _signOut,
                    icon: _signingOut
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value, textAlign: TextAlign.right, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('successBanner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F4E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF1E7A3C)),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF14532D)))),
        ],
      ),
    );
  }
}

/// Asks for the CURRENT password (obscured) to re-authenticate.
/// Returns the password, or null if cancelled. Nothing is logged or saved.
class _ReauthDialog extends StatefulWidget {
  const _ReauthDialog({required this.email, this.errorText});

  final String email;
  final String? errorText;

  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm it\'s you'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'For security, Firebase needs a recent sign-in before changing your password. '
              'Enter the current password for ${widget.email}.',
            ),
            const SizedBox(height: 16),
            if (widget.errorText != null) ...[
              ErrorBanner(message: widget.errorText!),
              const SizedBox(height: 12),
            ],
            PasswordField(
              key: const Key('currentPasswordField'),
              controller: _controller,
              label: 'Current password',
              validator: (v) => validateRequired(v, 'Current password'),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _confirm(),
              autofillHints: const [AutofillHints.password],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
          onPressed: _confirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
