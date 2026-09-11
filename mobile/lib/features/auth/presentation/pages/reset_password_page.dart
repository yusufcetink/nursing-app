import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const _resendCooldownSeconds = 60;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldownSeconds = _resendCooldownSeconds;
  bool _resetSucceeded = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _startCooldown();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _cooldownTimer?.cancel();
    _codeController.dispose();
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
          code: _codeController.text,
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

    setState(() => _resetSucceeded = true);
  }

  Future<void> _resend() async {
    if (_cooldownSeconds > 0 ||
        AuthValidators.email(_emailController.text) != null) {
      return;
    }
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .forgotPassword(email: _emailController.text);
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
    _startCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sıfırlama kodu yeniden gönderildi.')),
    );
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownSeconds = _resendCooldownSeconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          _cooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    return AuthPageLayout(
      title: 'Yeni şifre oluşturun',
      subtitle: 'Emailinize gönderilen 6 haneli kodu ve yeni şifrenizi girin.',
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
              key: const Key('reset_password_code_field'),
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '6 haneli sıfırlama kodu',
                prefixIcon: Icon(Icons.password_outlined),
                counterText: '',
              ),
              autofillHints: const [AutofillHints.oneTimeCode],
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              validator: AuthValidators.verificationCode,
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
              onPressed: isLoading || _resetSucceeded ? null : _submit,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Şifreyi Güncelle'),
            ),
            if (_resetSucceeded) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Şifreniz güncellendi. Giriş yapabilirsiniz.',
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isLoading || _resetSucceeded || _cooldownSeconds > 0
                  ? null
                  : _resend,
              child: Text(
                _cooldownSeconds > 0
                    ? 'Yeniden gönder ($_cooldownSeconds sn)'
                    : 'Sıfırlama Kodunu Yeniden Gönder',
              ),
            ),
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
