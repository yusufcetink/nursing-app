import 'package:asli_app/features/analytics/application/activity_tracker.dart';
import 'package:asli_app/features/analytics/data/activity_repository.dart';
import 'package:asli_app/features/analytics/domain/activity_event.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

void main() {
  test(
    'new session resets duration and repeated resume does not duplicate views',
    () async {
      var now = DateTime.utc(2026, 9, 12);
      final repository = _RecordingActivityRepository();
      final tracker = ActivityTracker(repository, now: () => now);
      addTearDown(tracker.dispose);
      tracker.startSession();
      tracker.screenChanged('home');
      now = now.add(const Duration(seconds: 7));
      tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tracker.endSession();
      tracker.startSession();
      tracker.screenChanged('home');
      now = now.add(const Duration(seconds: 2));
      await tracker.endSession();
      expect(
        repository.events
            .where((e) => e.eventType == 'session_end')
            .map((e) => e.durationSeconds),
        [7, 2],
      );
      expect(
        repository.events.where((e) => e.eventType == 'screen_view'),
        hasLength(2),
      );
    },
  );

  test(
    'route context distinguishes lessons and restores IDs on return',
    () async {
      var now = DateTime.utc(2026, 9, 12);
      final repository = _RecordingActivityRepository();
      final tracker = ActivityTracker(repository, now: () => now);
      addTearDown(tracker.dispose);
      const first = ActivityContext(moduleId: 'module', lessonId: 'first');
      const second = ActivityContext(moduleId: 'module', lessonId: 'second');
      tracker.screenChanged('lesson', context: first);
      tracker.startSession();
      tracker.screenChanged('lesson', context: first);
      now = now.add(const Duration(seconds: 3));
      tracker.screenChanged('lesson', context: second);
      now = now.add(const Duration(seconds: 4));
      tracker.screenChanged('lesson', context: first);
      now = now.add(const Duration(seconds: 2));
      await tracker.endSession();
      final leaves = repository.events.where(
        (e) => e.eventType == 'screen_leave',
      );
      expect(leaves.map((e) => e.lessonId), ['first', 'second', 'first']);
      expect(leaves.map((e) => e.durationSeconds), [3, 4, 2]);
      expect(
        repository.events.where((e) => e.eventType == 'lesson_open'),
        hasLength(3),
      );
    },
  );

  test('quiz active duration excludes background and another screen', () async {
    var now = DateTime.utc(2026, 9, 12);
    final tracker = ActivityTracker(
      _RecordingActivityRepository(),
      now: () => now,
    );
    addTearDown(tracker.dispose);
    const context = ActivityContext(moduleId: 'module', lessonId: 'lesson');
    tracker.startSession();
    tracker.screenChanged('quiz', context: context);
    now = now.add(const Duration(seconds: 5));
    tracker.didChangeAppLifecycleState(AppLifecycleState.inactive);
    tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 10));
    tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
    now = now.add(const Duration(seconds: 2));
    tracker.screenChanged('profile');
    now = now.add(const Duration(minutes: 3));
    tracker.screenChanged('quiz', context: context);
    now = now.add(const Duration(seconds: 1));
    expect(tracker.activeScreenDuration('quiz', context).inSeconds, 8);
    await tracker.endSession();
  });

  testWidgets('small queues flush periodically without navigation', (
    tester,
  ) async {
    final repository = _RecordingActivityRepository();
    final tracker = ActivityTracker(repository);
    tracker.startSession();
    await tester.pump();
    tracker.screenChanged('home');
    await tester.pump(const Duration(seconds: 10));
    expect(
      repository.events.where((e) => e.eventType == 'screen_view'),
      hasLength(1),
    );
    await tracker.endSession();
    tracker.dispose();
  });

  test(
    'retry preserves IDs and logout waits for the in-flight batch',
    () async {
      final repository = _GatedActivityRepository();
      final tracker = ActivityTracker(repository);
      addTearDown(tracker.dispose);
      tracker.startSession();
      tracker.screenChanged('home');
      var ended = false;
      final end = tracker.endSession().then((_) => ended = true);
      await Future<void>.delayed(Duration.zero);
      expect(ended, isFalse);
      repository.gate.complete();
      await end;
      expect(repository.events.last.eventType, 'session_end');
      expect(
        repository.events.map((e) => e.clientEventId).toSet().length,
        repository.events.length,
      );
    },
  );

  test('failed logout queue cannot be sent as the next user', () async {
    final repository = _FailingActivityRepository();
    final tracker = ActivityTracker(repository);
    addTearDown(tracker.dispose);
    tracker.startSession();
    tracker.screenChanged('home');
    await tracker.flush();
    final firstId = repository.attempts.first.first.clientEventId;
    await tracker.flush();
    expect(repository.attempts.last.first.clientEventId, firstId);
    await tracker.endSession();
    repository.fail = false;
    tracker.startSession();
    await tracker.endSession();
    expect(repository.events.any((e) => e.clientEventId == firstId), isFalse);
  });
  test(
    'background time is excluded from screen and session duration',
    () async {
      var now = DateTime.utc(2026, 9, 12, 10);
      final repository = _RecordingActivityRepository();
      final tracker = ActivityTracker(repository, now: () => now);

      tracker.startSession();
      tracker.screenChanged('lesson');
      now = now.add(const Duration(seconds: 10));
      tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 5));
      tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
      now = now.add(const Duration(seconds: 5));
      await tracker.endSession();

      final events = repository.events;
      final sessionEnd = events.singleWhere(
        (event) => event.eventType == 'session_end',
      );
      final screenSeconds = events
          .where((event) => event.eventType == 'screen_leave')
          .fold<int>(0, (sum, event) => sum + (event.durationSeconds ?? 0));
      expect(sessionEnd.durationSeconds, 15);
      expect(screenSeconds, 15);
      tracker.dispose();
    },
  );
}

final class _GatedActivityRepository implements ActivityRepository {
  final gate = Completer<void>();
  final List<ActivityEvent> events = [];
  @override
  Future<void> sendBatch(List<ActivityEvent> events) async {
    await gate.future;
    this.events.addAll(events);
  }
}

final class _FailingActivityRepository implements ActivityRepository {
  bool fail = true;
  final List<List<ActivityEvent>> attempts = [];
  final List<ActivityEvent> events = [];
  @override
  Future<void> sendBatch(List<ActivityEvent> events) async {
    attempts.add(events);
    if (fail) throw StateError('offline');
    this.events.addAll(events);
  }
}

final class _RecordingActivityRepository implements ActivityRepository {
  final List<ActivityEvent> events = [];

  @override
  Future<void> sendBatch(List<ActivityEvent> events) async {
    this.events.addAll(events);
  }
}
