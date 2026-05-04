import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_providers.dart';

/// Forced password change screen.
///
/// Shown when AuthState is AuthPasswordChangeRequired (first login flow).
/// On success, state promotes to AuthAuthenticated and the router auto-
/// navigates to home.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSubmitting = true);

    try {
      await ref.read(authStateProvider.notifier).changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
            newPasswordConfirmation: _confirmController.text,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Router will auto-navigate to home as state promotes to AuthAuthenticated.
    } on ApiException catch (e) {
      if (!mounted) return;

      // Show validation errors inline if backend returned 422 with field errors
      if (e.isValidationError && e.validationErrors != null) {
        final firstError = e.validationErrors!.entries.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${firstError.key}: ${firstError.value.first}'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleCancel() async {
    // Cancel forces logout — user can't bypass the password change.
    await ref.read(authStateProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = (authState is AuthPasswordChangeRequired)
        ? authState.user
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Password'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _handleCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppTheme.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Choose a new password',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user == null
                          ? 'Set a permanent password before continuing.'
                          : 'Hi ${user.name}, set a new password before continuing.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.slate500,
                          ),
                    ),
                    const SizedBox(height: 28),
                    _PasswordInput(
                      controller: _currentController,
                      label: 'Current (temporary) password',
                      obscure: _obscureCurrent,
                      enabled: !_isSubmitting,
                      onToggleObscure: () => setState(
                        () => _obscureCurrent = !_obscureCurrent,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if ((v ?? '').isEmpty) {
                          return 'Current password is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _PasswordInput(
                      controller: _newController,
                      label: 'New password',
                      obscure: _obscureNew,
                      enabled: !_isSubmitting,
                      onToggleObscure: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return 'New password is required.';
                        if (value.length < 8) {
                          return 'Must be at least 8 characters.';
                        }
                        if (value == _currentController.text) {
                          return 'New password must differ from current.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _PasswordInput(
                      controller: _confirmController,
                      label: 'Confirm new password',
                      obscure: _obscureConfirm,
                      enabled: !_isSubmitting,
                      onToggleObscure: () => setState(
                        () => _obscureConfirm = !_obscureConfirm,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted:
                          _isSubmitting ? null : (_) => _handleSubmit(),
                      validator: (v) {
                        if ((v ?? '').isEmpty) {
                          return 'Please confirm your new password.';
                        }
                        if (v != _newController.text) {
                          return 'Passwords do not match.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Update Password'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Password must be at least 8 characters.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.slate500,
                          ),
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

class _PasswordInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final bool enabled;
  final VoidCallback onToggleObscure;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final String? Function(String?) validator;

  const _PasswordInput({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.enabled,
    required this.onToggleObscure,
    required this.textInputAction,
    required this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show' : 'Hide',
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: enabled ? onToggleObscure : null,
        ),
      ),
      validator: validator,
    );
  }
}
