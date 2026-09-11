import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/core/config/app_config.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';

class LessonPage extends ConsumerWidget {
  const LessonPage({required this.moduleId, required this.lessonId, super.key});

  final String moduleId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(
      lessonProvider((moduleId: moduleId, lessonId: lessonId)),
    );
    return lessonAsync.when(
      loading: () => const Scaffold(body: ContentLoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ContentErrorView(
          message: networkErrorMessage(error),
          onRetry: () => ref.invalidate(
            lessonProvider((moduleId: moduleId, lessonId: lessonId)),
          ),
        ),
      ),
      data: (lesson) => _LessonContent(moduleId: moduleId, lesson: lesson),
    );
  }
}

class _LessonContent extends ConsumerStatefulWidget {
  const _LessonContent({required this.moduleId, required this.lesson});
  final String moduleId;
  final Lesson lesson;

  @override
  ConsumerState<_LessonContent> createState() => _LessonContentState();
}

class _LessonContentState extends ConsumerState<_LessonContent> {
  bool _saving = false;

  Future<void> _completeLesson() async {
    if (_saving) return;
    setState(() => _saving = true);
    final completed = await ref
        .read(progressControllerProvider.notifier)
        .completeLesson(widget.lesson.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!completed) {
      final error = ref
          .read(progressControllerProvider.notifier)
          .lastActionError;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(networkErrorMessage(error!))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final isCompleted = ref.watch(lessonCompletedProvider(lesson.id));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Öğrenme zamanı')),
      body: LearningBody(
        children: [
          Row(
            children: [
              LearningPill('DERS ${lesson.order.toString().padLeft(2, '0')}'),
              const Spacer(),
              if (isCompleted)
                LearningPill(
                  'Tamamlandı',
                  icon: Icons.check_rounded,
                  color: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(lesson.title, style: theme.textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(
            lesson.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          LearningPanel(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kendi ritminde öğren.',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tahmini süre: ${lesson.estimatedDurationMinutes} dakika',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const LearningArt(size: 96),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Text(
                'ANLATIM',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.8,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),
          for (final block in lesson.blocks) ...[
            if (block.blockType == LessonContentBlockType.heading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  block.textContent ?? '',
                  style: theme.textTheme.headlineSmall,
                ),
              )
            else if (block.blockType == LessonContentBlockType.text)
              SelectableText(
                block.textContent ?? '',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
              )
            else if (block.blockType == LessonContentBlockType.image &&
                block.media != null)
              _LessonImage(media: block.media!)
            else if (block.blockType == LessonContentBlockType.video &&
                block.media != null)
              _LessonVideoPlayer(media: block.media!),
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 16),
          LearningPanel(
            color: scheme.secondaryContainer,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.task_alt_rounded
                      : Icons.lightbulb_outline_rounded,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isCompleted
                        ? 'Bir adım daha attın. Öğrendiklerini pekiştir.'
                        : 'Hazır olduğunda bu adımı tamamlayabilirsin.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LearningAction(
            busy: _saving,
            label: !isCompleted
                ? 'Dersi Tamamla'
                : lesson.quizId == null
                ? 'Ders tamamlandı'
                : "Quiz'e Geç",
            onPressed: isCompleted && lesson.quizId == null
                ? null
                : () {
                    if (isCompleted) {
                      context.pushNamed(
                        AppRoutes.quiz,
                        pathParameters: {
                          AppRoutes.moduleIdParameter: widget.moduleId,
                          AppRoutes.lessonIdParameter: lesson.id,
                        },
                      );
                    } else {
                      _completeLesson();
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _LessonVideoPlayer extends ConsumerStatefulWidget {
  const _LessonVideoPlayer({required this.media});

  final LessonMedia media;

  @override
  ConsumerState<_LessonVideoPlayer> createState() => _LessonVideoPlayerState();
}

class _LessonVideoPlayerState extends ConsumerState<_LessonVideoPlayer> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final headers = await ref.read(apiClientProvider).authorizationHeaders();
      if (!headers.containsKey('Authorization')) {
        throw StateError('Video için oturum bilgisi bulunamadı.');
      }
      final controller = VideoPlayerController.networkUrl(
        _lessonMediaUri(widget.media),
        httpHeaders: headers,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(child: Text('Video yüklenemedi.')),
            )
          else if (controller == null)
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            AspectRatio(
              aspectRatio: controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: EdgeInsets.zero,
            ),
          ],
          ListTile(
            title: Text(widget.media.originalFileName),
            leading: IconButton(
              tooltip: controller?.value.isPlaying == true
                  ? 'Duraklat'
                  : 'Oynat',
              onPressed: controller == null
                  ? null
                  : () async {
                      if (controller.value.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }
                      if (mounted) setState(() {});
                    },
              icon: Icon(
                controller?.value.isPlaying == true
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonImage extends ConsumerStatefulWidget {
  const _LessonImage({required this.media});

  final LessonMedia media;

  @override
  ConsumerState<_LessonImage> createState() => _LessonImageState();
}

class _LessonImageState extends ConsumerState<_LessonImage> {
  late final Future<Map<String, String>> _headers;

  @override
  void initState() {
    super.initState();
    _headers = ref.read(apiClientProvider).authorizationHeaders();
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<Map<String, String>>(
          future: _headers,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: Text('Görsel yüklenemedi.')),
              );
            }
            if (!snapshot.hasData) {
              return const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Image.network(
              _lessonMediaUri(widget.media).toString(),
              headers: snapshot.data,
              width: double.infinity,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (context, error, stackTrace) => const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: Text('Görsel yüklenemedi.')),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: Text(widget.media.originalFileName),
        ),
      ],
    ),
  );
}

Uri _lessonMediaUri(LessonMedia media) {
  final baseUrl = AppConfig.apiBaseUrl.endsWith('/')
      ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
      : AppConfig.apiBaseUrl;
  return Uri.parse(
    '$baseUrl/api/education/lessons/${media.lessonId}/media/${media.id}',
  );
}
