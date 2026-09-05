import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/auth/presentation/validation/auth_validators.dart';
import 'package:asli_app/features/auth/presentation/widgets/auth_page_layout.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({required this.initialEmail, super.key});

  final String initialEmail;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(
          email: _emailController.text,
          token: _tokenController.text,
          newPassword: _passwordController.text,
        );
    if (!mounted) return;
    if (!succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authErrorMessage(ref.read(authControllerProvider).error),
          ),
        ),
      );
      return;
    }

    context.goNamed(AppRoutes.login);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Şifreniz güncellendi. Giriş yapabilirsiniz.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    return AuthPageLayout(
      title: 'Yeni şifre oluşturun',
      subtitle: 'Emaildeki kodu ve yeni şifrenizi girin.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('reset_password_email_field'),
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('reset_password_token_field'),
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Şifre sıfırlama kodu',
                prefixIcon: Icon(Icons.key_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  AuthValidators.requiredField(value, 'Şifre sıfırlama kodu'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('reset_password_new_password_field'),
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Yeni şifre',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.password,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('reset_password_confirmation_field'),
              controller: _confirmationController,
              decoration: const InputDecoration(
                labelText: 'Yeni şifre tekrarı',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: (value) => AuthValidators.passwordConfirmation(
                value,
                _passwordController.text,
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: isLoading ? null : _submit,
              child: const Text('Şifreyi Güncelle'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => context.goNamed(AppRoutes.login),
              child: const Text('Giriş ekranına dön'),
            ),
          ],
        ),
      ),
    );
  }
}
