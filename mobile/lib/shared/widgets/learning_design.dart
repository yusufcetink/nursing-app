import 'package:flutter/material.dart';
import 'package:asli_app/app/theme/app_radius.dart';
import 'package:asli_app/app/theme/app_spacing.dart';

/// The decorative artwork is separate from live, accessible Flutter controls.
enum LearningArtwork { book, medal, shield, heart }

class LearningArt extends StatelessWidget {
  const LearningArt({
    this.artwork = LearningArtwork.book,
    this.size = 140,
    super.key,
  });
  final LearningArtwork artwork;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      switch (artwork) {
        LearningArtwork.book => 'assets/illustrations/learning-book.png',
        LearningArtwork.medal => 'assets/illustrations/achievement-medal.png',
        LearningArtwork.shield => 'assets/illustrations/patient-shield.png',
        LearningArtwork.heart => 'assets/illustrations/clinical-heart.png',
      },
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: size <= 96 ? 256 : 512,
      filterQuality: FilterQuality.medium,
    ),
  );
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Aslı App',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'aslı',
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(letterSpacing: -1.8),
        ),
        const SizedBox(width: 5),
        CustomPaint(
          size: const Size(26, 30),
          painter: _BrandSparkPainter(
            Theme.of(context).colorScheme.secondaryFixedDim,
          ),
        ),
      ],
    ),
  );
}

class _BrandSparkPainter extends CustomPainter {
  const _BrandSparkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w * .62, h * .36, w * .66, h * .39, w, h / 2)
      ..cubicTo(w * .66, h * .61, w * .62, h * .64, w / 2, h)
      ..cubicTo(w * .38, h * .64, w * .34, h * .61, 0, h / 2)
      ..cubicTo(w * .34, h * .39, w * .38, h * .36, w / 2, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BrandSparkPainter oldDelegate) =>
      oldDelegate.color != color;
}

class LearningPanel extends StatelessWidget {
  const LearningPanel({
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.extraLarge),
    ),
    child: child,
  );
}

class LearningPill extends StatelessWidget {
  const LearningPill(
    this.label, {
    this.icon,
    this.color,
    this.foreground,
    super.key,
  });
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 17,
              color: foreground ?? scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: foreground ?? scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LearningAction extends StatelessWidget {
  const LearningAction({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.style,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: style,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.arrow_forward_rounded, size: 22),
        ],
      ),
    ),
  );
}

class LearningBody extends StatelessWidget {
  const LearningBody({
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(24, 12, 24, 32),
    super.key,
  });
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSpacing.readingContentWidth,
        ),
        child: ListView(padding: padding, children: children),
      ),
    ),
  );
}

class LearningStat extends StatelessWidget {
  const LearningStat({required this.value, required this.label, super.key});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.displaySmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ],
  );
}
