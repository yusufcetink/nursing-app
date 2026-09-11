import 'package:flutter/material.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';

class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    required this.title,
    required this.subtitle,
    required this.child,
    this.showIllustration = false,
    super.key,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final bool showIllustration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artHeight = (constraints.maxHeight * .26).clamp(96.0, 220.0);
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.compactContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        decoration: BoxDecoration(
                          color: showIllustration
                              ? theme.colorScheme.primaryContainer
                              : null,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const BrandWordmark(),
                            if (showIllustration) ...[
                              Text(
                                'Hemşirelik öğrenme alanın',
                                style: theme.textTheme.bodySmall,
                              ),
                              Center(child: LearningArt(size: artHeight)),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: showIllustration
                                  ? theme.textTheme.displaySmall
                                  : theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            child,
                          ],
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
