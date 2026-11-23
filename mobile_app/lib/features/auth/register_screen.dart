import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';
import 'auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Don't carry an error over from the login screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    final registered = await authProvider.register(
      email: email,
      password: password,
      fullName: name.isEmpty ? null : name,
    );
    if (!registered || !mounted) return;

    // Sign straight in with the new account.
    final loggedIn = await authProvider.login(email: email, password: password);
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      loggedIn ? AppRoutes.dashboard : AppRoutes.login,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    final visibility = IconButton(
      tooltip: _obscurePassword ? 'Show password' : 'Hide password',
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        size: 20,
      ),
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.surface),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create your account',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Liyana keeps your tasks, reminders and chats in one place.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      LabeledField(
                        label: 'Full name (optional)',
                        controller: _nameController,
                        hint: 'e.g. Ayesha Khan',
                        icon: Icons.person_outline,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        validator: (value) =>
                            (value != null && value.trim().length > 255)
                            ? 'Name is too long'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      LabeledField(
                        label: 'Email',
                        controller: _emailController,
                        hint: 'you@example.com',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 18),
                      LabeledField(
                        label: 'Password',
                        controller: _passwordController,
                        hint: 'At least 8 characters',
                        icon: Icons.lock_outline,
                        obscure: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: validatePassword,
                        suffix: visibility,
                      ),
                      const SizedBox(height: 18),
                      LabeledField(
                        label: 'Confirm password',
                        controller: _confirmController,
                        hint: 'Type it again',
                        icon: Icons.lock_outline,
                        obscure: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _register(),
                        validator: (value) => value != _passwordController.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      if (authProvider.errorMessage != null) ...[
                        ErrorBanner(message: authProvider.errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      PrimaryButton(
                        label: 'Create account',
                        loading: authProvider.isLoading,
                        onPressed: _register,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: theme.textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: authProvider.isLoading
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Sign in'),
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
      ),
    );
  }
}
