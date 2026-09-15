import 'package:flutter/material.dart';

class PublicationStatus extends StatelessWidget {
  const PublicationStatus({required this.isPublished, super.key});
  final bool isPublished;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = isPublished
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;
    return Chip(
      backgroundColor: isPublished
          ? scheme.tertiaryContainer
          : scheme.secondaryContainer,
      side: BorderSide.none,
      avatar: Icon(
        isPublished
            ? Icons.check_circle_outline_rounded
            : Icons.edit_note_rounded,
        size: 18,
        color: foreground,
      ),
      label: Text(
        isPublished ? 'Yayında' : 'Taslak',
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: foreground),
      ),
    );
  }
}
