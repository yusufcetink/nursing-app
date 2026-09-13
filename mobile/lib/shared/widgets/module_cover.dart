import 'package:flutter/material.dart';

/// Presentation-only fallback until the API supplies module artwork metadata.
/// Uses the title, never module order or user data, to choose a stable cover.
enum NursingCover {
  vital('vital-signs'),
  pain('pain-management'),
  safety('patient-safety'),
  infection('infection-control'),
  medication('medication'),
  wound('wound-care'),
  general(null);

  const NursingCover(this.fileName);
  final String? fileName;

  String? get assetPath =>
      fileName == null ? null : 'assets/illustrations/modules/$fileName.png';

  static NursingCover forTitle(String title) {
    final normalized = title
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    if (normalized.contains('vital') || normalized.contains('yasam bulgu')) {
      return vital;
    }
    if (normalized.contains('agri')) return pain;
    if (normalized.contains('hasta guven')) return safety;
    if (normalized.contains('enfeksiyon')) return infection;
    if (normalized.contains('ilac')) return medication;
    if (normalized.contains('yara')) return wound;
    return general;
  }
}

class ModuleCover extends StatelessWidget {
  const ModuleCover({required this.title, this.aspectRatio = 1.5, super.key});
  final String title;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final asset = NursingCover.forTitle(title).assetPath;
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: asset == null
            ? const _CoverFallback()
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                cacheWidth: 960,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const _CoverFallback(),
              ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.primaryContainer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FractionallySizedBox(
            widthFactor: .65,
            heightFactor: .85,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.secondaryContainer,
              ),
            ),
          ),
          Image.asset(
            'assets/illustrations/learning-book.png',
            fit: BoxFit.contain,
            cacheWidth: 512,
            errorBuilder: (_, _, _) => Icon(
              Icons.auto_stories_rounded,
              size: 72,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
