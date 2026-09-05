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

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({required this.email, super.key});

  final String email;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  static const _resendCooldownSeconds = 60;
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldownSeconds = _resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .verifyEmail(email: widget.email, code: _codeController.text);
    if (!mounted) return;
    if (!succeeded) {
      _showError();
      return;
    }

    context.goNamed(AppRoutes.login);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email doğrulandı. Şimdi giriş yapabilirsiniz.'),
      ),
    );
  }

  Future<void> _resend() async {
    if (_cooldownSeconds > 0) return;
    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .resendVerification(email: widget.email);
    if (!mounted) return;
    if (!succeeded) {
      _showError();
      return;
    }
    _startCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hesap uygunsa doğrulama emaili yeniden gönderildi.'),
      ),
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

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authErrorMessage(ref.read(authControllerProvider).error)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    return AuthPageLayout(
      title: 'Email adresinizi doğrulayın',
      subtitle: '${widget.email} adresine gönderilen kodu girin.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('verification_code_field'),
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '6 haneli doğrulama kodu',
                prefixIcon: Icon(Icons.verified_user_outlined),
                counterText: '',
              ),
              autofocus: true,
              autofillHints: const [AutofillHints.oneTimeCode],
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 10),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              validator: AuthValidators.verificationCode,
              onFieldSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: isLoading ? null : _verify,
              child: const Text('Emaili Doğrula'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isLoading || _cooldownSeconds > 0 ? null : _resend,
              child: Text(
                _cooldownSeconds > 0
                    ? 'Yeniden gönder ($_cooldownSeconds sn)'
                    : 'Doğrulama Emailini Yeniden Gönder',
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
