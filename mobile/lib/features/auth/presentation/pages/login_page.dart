import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/auth/presentation/validation/auth_validators.dart';
import 'package:asli_app/features/auth/presentation/widgets/auth_page_layout.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) {
      return;
    }
    if (succeeded) {
      context.goNamed(AppRoutes.home);
      return;
    }

    final error = ref.read(authControllerProvider).error;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AuthPageLayout(
      title: 'Tekrar hoş geldiniz',
      subtitle: 'Eğitimlerinize devam etmek için giriş yapın.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('login_email_field'),
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: AuthValidators.email,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('login_password_field'),
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: AuthValidators.password,
              onFieldSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.goNamed(AppRoutes.forgotPassword),
                child: const Text('Şifremi unuttum'),
              ),
            ),
            FilledButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Giriş Yap'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => context.goNamed(AppRoutes.register),
              child: const Text('Hesabınız yok mu? Kayıt Ol'),
            ),
          ],
        ),
      ),
    );
  }
}
