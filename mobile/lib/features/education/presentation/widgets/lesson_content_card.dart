import 'package:flutter/material.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';

class LessonContentCard extends StatelessWidget {
  const LessonContentCard({required this.block, super.key});
  final LessonContentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = (block.textContent ?? '').split('\n');
    final icon = switch (block.blockType) {
      LessonContentBlockType.caseStudy => Icons.person_search_outlined,
      LessonContentBlockType.comparison => Icons.compare_arrows_rounded,
      LessonContentBlockType.summary => Icons.checklist_rounded,
      LessonContentBlockType.recall => Icons.lightbulb_outline,
      _ => Icons.info_outline,
    };
    return Card(
      margin: EdgeInsets.zero,
      color: block.blockType == LessonContentBlockType.callout
          ? scheme.tertiaryContainer
          : scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: block.blockType == LessonContentBlockType.callout
                  ? scheme.onTertiaryContainer
                  : scheme.primary,
            ),
            const SizedBox(height: 12),
            Text(lines.first, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final line in lines.skip(1).where((line) => line.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableText(
                  line,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
