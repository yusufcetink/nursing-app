import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/features/analytics/application/activity_tracker.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';
import 'package:asli_app/shared/widgets/module_cover.dart';

/// Home's compact shelf and illustrated continuation card share live progress.
class HomeModuleCard extends ConsumerWidget {
  const HomeModuleCard({
    required this.module,
    required this.onOpen,
    this.hero = false,
    super.key,
  });
  final EducationModule module;
  final VoidCallback onOpen;
  final bool hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final availability = ref.watch(
      progressControllerProvider.select(
        (state) => (
          known: state.hasValue && !state.hasError,
          hasError: state.hasError,
        ),
      ),
    );
    final progress = ref.watch(moduleProgressProvider(module)).clamp(0.0, 1.0);
    final known = availability.known;
    final count = (progress * module.lessonCount).round();
    final completed = known && module.lessonCount > 0 && progress >= 1;
    final caption = !known
        ? availability.hasError
              ? 'İlerleme yüklenemedi'
              : 'İlerleme yükleniyor…'
        : module.lessonCount == 0
        ? 'Dersler hazırlanıyor'
        : '$count / ${module.lessonCount} ders';
    final action = module.lessonCount == 0
        ? 'Modülü incele'
        : completed
        ? 'Yeniden incele'
        : hero
        ? progress > 0
              ? 'Öğrenmeye devam et'
              : 'Öğrenmeye başla'
        : progress > 0
        ? 'Devam et'
        : 'Başla';
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
    final title = Text(
      module.title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontSize: hero ? 24 : 18,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: hero ? -.8 : -.3,
      ),
    );
    final description = Text(
      module.description,
      maxLines: largeText ? null : 2,
      overflow: largeText ? null : TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
    );
    return Material(
      color: scheme.surface,
      elevation: hero ? 2 : 0,
      shadowColor: scheme.shadow.withValues(alpha: .12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(hero ? 26 : 20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .3)),
      ),
      child: InkWell(
        onTap: onOpen,
        child: hero
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      ModuleCover(
                        title: module.title,
                        aspectRatio: 2.1,
                        alignment: Alignment.topCenter,
                      ),
                      Positioned(
                        top: 10,
                        left: 9,
                        right: 9,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: LearningPill(
                            completed
                                ? 'BİLGİNİ TAZELE'
                                : known && progress == 0
                                ? 'İLK ADIMIN'
                                : 'KALDIĞIN YERDEN',
                            color: scheme.primaryContainer,
                            foreground: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  CustomPaint(
                    painter: _PanelWave(scheme.surface),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (known && module.lessonCount > 0 && !largeText)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      title,
                                      const SizedBox(height: 5),
                                      description,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _ProgressArc(
                                  count: count,
                                  total: module.lessonCount,
                                ),
                              ],
                            )
                          else ...[
                            title,
                            const SizedBox(height: 5),
                            description,
                            const SizedBox(height: 8),
                            Text(caption, style: theme.textTheme.bodySmall),
                          ],
                          const SizedBox(height: 12),
                          LearningAction(
                            label: action,
                            onPressed: onOpen,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 7,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ModuleCover(title: module.title, aspectRatio: 1.8),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 6),
                        description,
                        const SizedBox(height: 14),
                        Text(
                          caption,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: known ? progress : null,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(10),
                          semanticsLabel: '${module.title} ilerlemesi',
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(activityTrackerProvider)
                                .track('button_click', target: action);
                            onOpen();
                          },
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 48),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: action),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProgressArc extends StatelessWidget {
  const _ProgressArc({required this.count, required this.total});
  final int count;
  final int total;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$total dersten $count ders tamamlandı',
    excludeSemantics: true,
    child: SizedBox(
      width: 94,
      height: 65,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ArcPainter(
                count / total,
                total,
                Theme.of(context).colorScheme,
              ),
            ),
          ),
          Positioned(
            top: 29,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  '$count / $total',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                Text(
                  'ders tamamlandı',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter(this.progress, this.total, this.scheme);
  final double progress;
  final int total;
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size size) {
    final segments = total.clamp(1, 12);
    final step = math.pi / segments;
    final gap = math.min(.34, step * .65);
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, 40),
      radius: 38,
    );
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(
        rect,
        math.pi + i * step + gap / 2,
        step - gap,
        false,
        Paint()
          ..color = i / segments < progress
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: .16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.total != total || old.scheme != scheme;
}

class _PanelWave extends CustomPainter {
  const _PanelWave(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * .62, 0)
        ..cubicTo(size.width * .76, -24, size.width * .85, -9, size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PanelWave old) => old.color != color;
}

class HomeActivitySun extends StatelessWidget {
  const HomeActivitySun({super.key});
  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: CustomPaint(size: Size(48, 36), painter: _SunPainter()),
  );
}

class _SunPainter extends CustomPainter {
  const _SunPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xfff47b59);
    final center = Offset(size.width / 2, size.height - 3);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 12),
      math.pi,
      math.pi,
      true,
      paint,
    );
    paint
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= 6; i++) {
      final direction = Offset(
        math.cos(math.pi + i * math.pi / 6),
        math.sin(math.pi + i * math.pi / 6),
      );
      canvas.drawLine(center + direction * 18, center + direction * 23, paint);
    }
  }

  @override
  bool shouldRepaint(_SunPainter old) => false;
}
