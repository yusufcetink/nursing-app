import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/auth/presentation/validation/auth_validators.dart';
import 'package:asli_app/features/auth/presentation/widgets/auth_page_layout.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final succeeded = await ref
        .read(authControllerProvider.notifier)
        .register(
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) {
      return;
    }
    if (succeeded) {
      context.goNamed(
        AppRoutes.emailVerification,
        queryParameters: {'email': _emailController.text.trim()},
      );
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
      title: 'Hesap oluşturun',
      subtitle: 'Eğitim yolculuğunuza başlamak için bilgilerinizi girin.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('register_first_name_field'),
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Ad',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              validator: (value) => AuthValidators.requiredField(value, 'Ad'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('register_last_name_field'),
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Soyad',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.familyName],
              validator: (value) =>
                  AuthValidators.requiredField(value, 'Soyad'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('register_email_field'),
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              validator: AuthValidators.email,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('register_password_field'),
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: AuthValidators.password,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('register_password_confirmation_field'),
              controller: _passwordConfirmationController,
              decoration: const InputDecoration(
                labelText: 'Şifre Tekrarı',
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
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kayıt Ol'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => context.goNamed(AppRoutes.login),
              child: const Text('Zaten hesabınız var mı? Giriş Yap'),
            ),
          ],
        ),
      ),
    );
  }
}
