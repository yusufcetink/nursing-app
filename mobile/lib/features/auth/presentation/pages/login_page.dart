import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/auth/presentation/validation/auth_validators.dart';
import 'package:asli_app/features/auth/presentation/widgets/auth_page_layout.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authControllerProvider).isLoading) return;
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
      showIllustration: true,
      title: 'Bilgin büyüsün.\nGüvenin artsın.',
      subtitle: 'Küçük adımlarla, kendi ritminde öğren.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('login_email_field'),
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'E-posta',
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
              decoration: InputDecoration(
                labelText: 'Şifre',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _passwordVisible
                      ? 'Şifreyi gizle'
                      : 'Şifreyi göster',
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  icon: Icon(
                    _passwordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              obscureText: !_passwordVisible,
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
            LearningAction(
              label: 'Giriş Yap',
              busy: isLoading,
              onPressed: isLoading ? null : _submit,
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
