import 'package:flutter/material.dart';
import 'package:asli_app/app/theme/app_radius.dart';
import 'package:asli_app/app/theme/app_spacing.dart';

class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pagePadding =
                constraints.maxWidth >= AppSpacing.wideScreenBreakpoint
                ? AppSpacing.xl
                : AppSpacing.md;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: pagePadding,
                  vertical: AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.compactContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppRadius.extraLarge,
                            ),
                          ),
                          child: Icon(
                            Icons.local_hospital_rounded,
                            size: AppSpacing.xxl,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'ASLI APP',
                        textAlign: TextAlign.center,
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
