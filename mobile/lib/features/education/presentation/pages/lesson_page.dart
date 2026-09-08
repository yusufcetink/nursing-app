import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_spacing.dart';
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

class _LessonContent extends ConsumerWidget {
  const _LessonContent({required this.moduleId, required this.lesson});

  final String moduleId;
  final Lesson lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonId = lesson.id;
    final isCompleted = ref.watch(lessonCompletedProvider(lessonId));

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.readingContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.section,
              ),
              children: [
                Card(
                  color: colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          lesson.description,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 20,
                              color: colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Tahmini süre: ${lesson.estimatedDurationMinutes} dakika',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colorScheme.onTertiaryContainer,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final block in lesson.blocks) ...[
                  if (block.blockType == LessonContentBlockType.heading)
                    Text(
                      block.textContent ?? '',
                      style: Theme.of(context).textTheme.headlineSmall,
                    )
                  else if (block.blockType == LessonContentBlockType.text)
                    Text(
                      block.textContent ?? '',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  else if (block.blockType == LessonContentBlockType.image &&
                      block.media != null)
                    _LessonImage(media: block.media!)
                  else if (block.blockType == LessonContentBlockType.video &&
                      block.media != null)
                    _LessonVideoPlayer(media: block.media!),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isCompleted && lesson.quizId == null
                        ? null
                        : () async {
                            if (isCompleted) {
                              context.pushNamed(
                                AppRoutes.quiz,
                                pathParameters: {
                                  AppRoutes.moduleIdParameter: moduleId,
                                  AppRoutes.lessonIdParameter: lessonId,
                                },
                              );
                              return;
                            }
                            final completed = await ref
                                .read(progressControllerProvider.notifier)
                                .completeLesson(lessonId);
                            if (!completed && context.mounted) {
                              final error = ref
                                  .read(progressControllerProvider.notifier)
                                  .lastActionError;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(networkErrorMessage(error!)),
                                ),
                              );
                            }
                          },
                    icon: Icon(
                      isCompleted && lesson.quizId != null
                          ? Icons.quiz_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
                    label: Text(
                      !isCompleted
                          ? 'Dersi Tamamla'
                          : lesson.quizId == null
                          ? 'Bu ders için quiz bulunmuyor'
                          : "Quiz'e Geç",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
