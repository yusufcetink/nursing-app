import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/shared/widgets/learning_design.dart';
import 'package:asli_app/features/education/presentation/providers/education_modules_provider.dart';
import 'package:asli_app/features/education/presentation/providers/lesson_completion_provider.dart';
import 'package:asli_app/features/education/presentation/widgets/lesson_completion_sheet.dart';
import 'package:asli_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/core/config/app_config.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';
import 'package:asli_app/shared/widgets/content_state_view.dart';
import 'package:asli_app/features/analytics/application/activity_tracker.dart';
import 'package:asli_app/features/education/presentation/widgets/lesson_detail_header.dart';

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
    final wasCompleted = ref.read(lessonCompletedProvider(widget.lesson.id));
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
    } else {
      ref
          .read(activityTrackerProvider)
          .track(
            'lesson_complete',
            moduleId: widget.moduleId,
            lessonId: widget.lesson.id,
          );
      if (!wasCompleted) {
        final completion = ref.read(lessonCompletionProvider(widget.moduleId));
        final continueLearning = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          useSafeArea: true,
          showDragHandle: true,
          sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : const AnimationStyle(
                  duration: Duration(milliseconds: 280),
                  reverseDuration: Duration(milliseconds: 180),
                ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .92,
          ),
          builder: (context) => LessonCompletionSheet(
            lessonTitle: widget.lesson.title,
            completion: completion,
            actionLabel: widget.lesson.quizId != null
                ? "Quiz'e Geç"
                : completion?.moduleCompleted == true
                ? 'Eğitim modüllerini keşfet'
                : completion?.nextLesson != null
                ? 'Sıradaki derse geç'
                : 'Modüle dön',
          ),
        );
        if (!mounted || continueLearning != true) return;
        if (widget.lesson.quizId != null) {
          context.pushNamed(
            AppRoutes.quiz,
            pathParameters: {
              AppRoutes.moduleIdParameter: widget.moduleId,
              AppRoutes.lessonIdParameter: widget.lesson.id,
            },
          );
        } else if (completion?.moduleCompleted == true) {
          context.goNamed(AppRoutes.home);
        } else if (completion?.nextLesson != null) {
          context.goNamed(
            AppRoutes.lesson,
            pathParameters: {
              AppRoutes.moduleIdParameter: widget.moduleId,
              AppRoutes.lessonIdParameter: completion!.nextLesson!.id,
            },
          );
        } else {
          context.goNamed(
            AppRoutes.educationModule,
            pathParameters: {AppRoutes.moduleIdParameter: widget.moduleId},
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    ref.watch(lessonCompletionProvider(widget.moduleId));
    final isCompleted = ref.watch(lessonCompletedProvider(lesson.id));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Aslı App'), centerTitle: true),
      body: LearningBody(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          LessonDetailHeader(lesson: lesson),
          const SizedBox(height: 28),
          Row(
            children: [
              Text(
                'ANLATIM',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.8,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 18),
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
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.55,
                  color: scheme.onSurfaceVariant,
                ),
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
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.task_alt_rounded
                      : Icons.check_circle_outline_rounded,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCompleted
                            ? 'Bir adım daha attın.'
                            : 'Hazır olduğunda',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCompleted
                            ? 'Öğrendiklerini pekiştir.'
                            : 'Bu adımı tamamlayarak ilerleyebilirsin.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LearningAction(
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
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
  bool _completedTracked = false;

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
      controller.addListener(_videoChanged);
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
    _controller?.removeListener(_videoChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final scheme = Theme.of(context).colorScheme;
    final playButton = IconButton.filled(
      tooltip: controller?.value.isPlaying == true ? 'Duraklat' : 'Oynat',
      onPressed: controller == null ? null : _togglePlayback,
      style: IconButton.styleFrom(
        minimumSize: const Size(56, 56),
        backgroundColor: scheme.inverseSurface.withValues(alpha: .9),
        foregroundColor: scheme.onInverseSurface,
      ),
      icon: Icon(
        controller?.value.isPlaying == true
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
        size: 32,
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
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
            Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: controller.value.aspectRatio > 0
                      ? controller.value.aspectRatio
                      : 16 / 9,
                  child: VideoPlayer(controller),
                ),
                playButton,
              ],
            ),
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: EdgeInsets.zero,
              colors: VideoProgressColors(
                playedColor: scheme.primary,
                bufferedColor: scheme.primary.withValues(alpha: .25),
                backgroundColor: scheme.outlineVariant,
              ),
            ),
          ],
          ListTile(
            title: Text(widget.media.originalFileName),
            subtitle: controller == null
                ? null
                : ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => Text(
                      '${_videoTime(value.position)} / ${_videoTime(value.duration)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _videoTime(Duration value) =>
      '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      ref
          .read(activityTrackerProvider)
          .track(
            'video_pause',
            target: widget.media.id,
            lessonId: widget.media.lessonId,
            metadata: {
              'positionSeconds': controller.value.position.inSeconds.toString(),
            },
          );
    } else {
      await controller.play();
      ref
          .read(activityTrackerProvider)
          .track(
            'video_play',
            target: widget.media.id,
            lessonId: widget.media.lessonId,
            metadata: {
              'positionSeconds': controller.value.position.inSeconds.toString(),
            },
          );
    }
    if (mounted) setState(() {});
  }

  void _videoChanged() {
    final controller = _controller;
    if (controller == null || _completedTracked) return;
    final duration = controller.value.duration;
    if (duration > Duration.zero && controller.value.position >= duration) {
      _completedTracked = true;
      ref
          .read(activityTrackerProvider)
          .track(
            'video_complete',
            target: widget.media.id,
            lessonId: widget.media.lessonId,
            durationSeconds: duration.inSeconds,
          );
    }
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
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant
            .withValues(alpha: .5),
      ),
    ),
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
