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
    final (label, icon, accent) = switch (block.blockType) {
      LessonContentBlockType.caseStudy => (
        'Klinik örnek',
        Icons.person_search_outlined,
        scheme.secondary,
      ),
      LessonContentBlockType.comparison => (
        'Karşılaştırma',
        Icons.compare_arrows_rounded,
        scheme.primary,
      ),
      LessonContentBlockType.summary => (
        'Özet',
        Icons.checklist_rounded,
        scheme.tertiary,
      ),
      LessonContentBlockType.recall => (
        'Kendini yokla',
        Icons.lightbulb_outline,
        scheme.secondary,
      ),
      _ => ('Önemli nokta', Icons.info_outline, scheme.primary),
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: .06), scheme.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Icon(icon, color: accent, size: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              lines.first,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          for (final line in lines.skip(1).where((line) => line.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: block.blockType == LessonContentBlockType.comparison
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        line,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                    )
                  : SelectableText(
                      line,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
            ),
        ],
      ),
    );
  }
}
