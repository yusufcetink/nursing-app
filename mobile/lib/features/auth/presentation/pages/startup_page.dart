import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';

class StartupPage extends ConsumerWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: authState.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: AppSpacing.xl),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        authErrorMessage(authState.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .restoreSession(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tekrar Dene'),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_outlined, size: AppSpacing.section),
                      SizedBox(height: AppSpacing.md),
                      Text('Aslı App'),
                      SizedBox(height: AppSpacing.lg),
                      CircularProgressIndicator(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
