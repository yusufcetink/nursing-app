import 'dart:async';
import 'dart:math';

import 'package:asli_app/features/analytics/data/activity_repository.dart';
import 'package:asli_app/features/analytics/domain/activity_event.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final activityTrackerProvider = Provider<ActivityTracker>((ref) {
  final tracker = ActivityTracker(ref.watch(activityRepositoryProvider));
  ref.onDispose(tracker.dispose);
  return tracker;
});

final class ActivityContext {
  const ActivityContext({this.moduleId, this.lessonId, this.quizId});

  final String? moduleId;
  final String? lessonId;
  final String? quizId;
}

final class ActivityTracker with WidgetsBindingObserver {
  ActivityTracker(
    this._repository, {
    DateTime Function()? now,
    this.flushInterval = const Duration(seconds: 10),
  }) : _now = now ?? DateTime.now;

  final ActivityRepository _repository;
  final DateTime Function() _now;
  final Duration flushInterval;
  Timer? _flushTimer;
  bool _ending = false;
  final Map<String, Duration> _screenDurations = {};
  final List<ActivityEvent> _queue = [];
  String? _sessionId;
  DateTime? _sessionActiveSince;
  Duration _sessionActiveDuration = Duration.zero;
  String? _screenName;
  DateTime? _screenActiveSince;
  ActivityContext _context = const ActivityContext();
  bool _foreground = true;
  Future<void>? _activeFlush;

  bool get hasSession => _sessionId != null;

  String _screenKey(String name, ActivityContext context) =>
      '$name/${context.moduleId ?? ''}/${context.lessonId ?? ''}';

  Duration activeScreenDuration(String name, ActivityContext context) {
    final key = _screenKey(name, context);
    final accumulated = _screenDurations[key] ?? Duration.zero;
    final since = _screenActiveSince;
    return accumulated +
        (since != null &&
                _screenName != null &&
                key == _screenKey(_screenName!, _context)
            ? _now().difference(since)
            : Duration.zero);
  }

  void startSession() {
    if (_sessionId != null || _ending) return;
    _sessionActiveDuration = Duration.zero;
    _screenDurations.clear();
    _sessionId = _uuid();
    _sessionActiveSince = _foreground ? _now() : null;
    _enqueue('session_start');
    if (_screenName != null && _foreground) {
      _screenActiveSince = _now();
      _enqueue('screen_view');
      _trackScreenOpen();
    }
    _flushTimer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
    unawaited(flush());
  }

  Future<void> endSession() async {
    if (_ending) {
      await flush();
      return;
    }
    if (_sessionId == null) return;
    _ending = true;
    _flushTimer?.cancel();
    _pauseActiveSegments();
    _enqueue('session_end', durationSeconds: _sessionActiveDuration.inSeconds);
    _sessionId = null;
    _screenName = null;
    await flush();
    // Unsent events must never be retried with the next user's credentials.
    if (_queue.isNotEmpty && kDebugMode) {
      debugPrint('[analytics] logout discarded ${_queue.length} unsent events');
    }
    _queue.clear();
    _context = const ActivityContext();
    _ending = false;
  }

  void screenChanged(
    String? name, {
    ActivityContext context = const ActivityContext(),
  }) {
    if (name == null ||
        (name == _screenName &&
            _screenKey(name, context) == _screenKey(name, _context))) {
      return;
    }
    _leaveScreen();
    _screenName = name;
    _context = context;
    if (_sessionId != null && _foreground) {
      _screenActiveSince = _now();
      _enqueue('screen_view', screenName: name);
      _trackScreenOpen();
    }
  }

  void _trackScreenOpen() {
    if (_screenName == 'education-module') _enqueue('module_open');
    if (_screenName == 'lesson') _enqueue('lesson_open');
  }

  void updateContext(ActivityContext context) => _context = context;

  void track(
    String eventType, {
    String? target,
    int? durationSeconds,
    String? moduleId,
    String? lessonId,
    String? quizId,
    String? questionId,
    Map<String, String>? metadata,
  }) {
    if (_sessionId == null) return;
    _enqueue(
      eventType,
      target: target,
      durationSeconds: durationSeconds,
      moduleId: moduleId ?? _context.moduleId,
      lessonId: lessonId ?? _context.lessonId,
      quizId: quizId ?? _context.quizId,
      questionId: questionId,
      metadata: metadata,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_foreground) return;
      _foreground = true;
      if (_sessionId == null) return;
      final now = _now();
      _sessionActiveSince = now;
      if (_screenName != null) {
        _screenActiveSince = now;
        _enqueue('screen_view', screenName: _screenName);
      }
      unawaited(flush());
      return;
    }
    if (_foreground &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached ||
            state == AppLifecycleState.hidden)) {
      _pauseActiveSegments();
      _foreground = false;
      unawaited(flush());
    }
  }

  Future<void> flush() {
    final active = _activeFlush;
    if (active != null) return active;
    if (_queue.isEmpty) return Future.value();
    final future = _drainQueue();
    _activeFlush = future;
    return future.whenComplete(() => _activeFlush = null);
  }

  void dispose() {
    _flushTimer?.cancel();
    _queue.clear();
  }

  Future<void> _drainQueue() async {
    while (_queue.isNotEmpty) {
      final batch = _queue.take(20).toList(growable: false);
      try {
        await _repository.sendBatch(batch);
        final sentIds = batch.map((event) => event.clientEventId).toSet();
        _queue.removeWhere((event) => sentIds.contains(event.clientEventId));
        if (kDebugMode) debugPrint('[analytics] batch sent: ${batch.length}');
      } on Object catch (error) {
        if (kDebugMode) {
          final detail = error is DioException
              ? '${error.type.name}, ${error.error.runtimeType}, HTTP ${error.response?.statusCode ?? '-'}'
              : error.runtimeType.toString();
          debugPrint(
            '[analytics] batch failed ($detail); queued: ${_queue.length}',
          );
        }
        // Analytics is best-effort; retain the bounded queue for a later retry.
        if (_queue.length > 200) _queue.removeRange(0, _queue.length - 200);
        return;
      }
    }
  }

  void _pauseActiveSegments() {
    final now = _now();
    final sessionStart = _sessionActiveSince;
    if (sessionStart != null) {
      _sessionActiveDuration += now.difference(sessionStart);
    }
    _sessionActiveSince = null;
    _leaveScreen(at: now);
  }

  void _leaveScreen({DateTime? at}) {
    final started = _screenActiveSince;
    final name = _screenName;
    if (started != null && name != null) {
      final elapsed = (at ?? _now()).difference(started);
      final key = _screenKey(name, _context);
      _screenDurations[key] =
          (_screenDurations[key] ?? Duration.zero) + elapsed;
      _enqueue(
        'screen_leave',
        screenName: name,
        durationSeconds: max(0, elapsed.inSeconds),
      );
    }
    _screenActiveSince = null;
  }

  void _enqueue(
    String eventType, {
    String? screenName,
    int? durationSeconds,
    String? moduleId,
    String? lessonId,
    String? quizId,
    String? questionId,
    String? target,
    Map<String, String>? metadata,
  }) {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    _queue.add(
      ActivityEvent(
        clientEventId: _uuid(),
        sessionId: sessionId,
        eventType: eventType,
        occurredAtUtc: _now().toUtc(),
        screenName: screenName ?? _screenName,
        durationSeconds: durationSeconds,
        moduleId: moduleId ?? _context.moduleId,
        lessonId: lessonId ?? _context.lessonId,
        quizId: quizId ?? _context.quizId,
        questionId: questionId,
        target: target,
        metadata: metadata,
      ),
    );
    if (_queue.length >= 10) unawaited(flush());
  }
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
