import 'package:asli_app/core/config/app_config.dart';
import 'package:asli_app/features/analytics/application/activity_tracker.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/notifications/application/local_inactivity_reminder_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_activity_repository.dart';
import '../../../helpers/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app open schedules one reminder 24 hours later', () async {
    final now = DateTime.utc(2026, 9, 13, 10);
    final gateway = _FakeGateway();
    final service = _service(gateway, now: () => now);

    await service.start();

    expect(gateway.permissionRequests, 1);
    expect(gateway.cancelCalls, [LocalInactivityReminderService.reminderId]);
    expect(gateway.pending, {
      LocalInactivityReminderService.reminderId: now.add(
        const Duration(hours: 24),
      ),
    });
    service.dispose();
  });

  test('foreground replaces the old reminder and restarts 24 hours', () async {
    var now = DateTime.utc(2026, 9, 13, 10);
    final gateway = _FakeGateway();
    final service = _service(gateway, now: () => now);
    await service.start();

    now = now.add(const Duration(hours: 5));
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await service.waitForPendingOperations();

    expect(gateway.cancelCalls, [
      LocalInactivityReminderService.reminderId,
      LocalInactivityReminderService.reminderId,
    ]);
    expect(gateway.pending, hasLength(1));
    expect(
      gateway.pending[LocalInactivityReminderService.reminderId],
      now.add(const Duration(hours: 24)),
    );
    service.dispose();
  });

  test(
    'development override schedules two minutes and release ignores it',
    () async {
      final now = DateTime.utc(2026, 9, 13, 10);
      final gateway = _FakeGateway();
      final developmentDelay = resolveInactivityReminderDelay(
        releaseMode: false,
        developmentMinutes: 2,
      );
      final service = _service(
        gateway,
        now: () => now,
        delay: developmentDelay,
      );

      await service.start();

      expect(
        gateway.pending[LocalInactivityReminderService.reminderId],
        now.add(const Duration(minutes: 2)),
      );
      expect(
        resolveInactivityReminderDelay(
          releaseMode: true,
          developmentMinutes: 2,
        ),
        const Duration(hours: 24),
      );
      service.dispose();
    },
  );

  test('logout does not cancel the device reminder', () async {
    final activityRepository = FakeActivityRepository();
    final container = ProviderContainer(
      overrides: [
        activityRepositoryProvider.overrideWithValue(activityRepository),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    final gateway = _FakeGateway();
    final service = LocalInactivityReminderService(
      container.read(activityTrackerProvider),
      gateway: gateway,
      delay: const Duration(hours: 24),
      now: () => DateTime.utc(2026, 9, 13, 10),
    );
    await service.start();

    expect(
      await container.read(authControllerProvider.notifier).logout(),
      isTrue,
    );

    expect(gateway.cancelCalls, hasLength(1));
    expect(gateway.pending, hasLength(1));
    service.dispose();
  });

  test('notification tap is recorded after the app session starts', () async {
    final repository = FakeActivityRepository();
    final tracker = ActivityTracker(
      repository,
      flushInterval: const Duration(days: 1),
    );
    final gateway = _FakeGateway(
      initialPayload: LocalInactivityReminderService.reminderPayload,
    );
    final service = LocalInactivityReminderService(
      tracker,
      gateway: gateway,
      delay: const Duration(hours: 24),
    );
    await service.start();

    tracker.startSession();
    service.flushPendingOpenedEvent();
    await tracker.flush();

    final opened = repository.events.singleWhere(
      (event) => event.eventType == 'notification_opened',
    );
    expect(opened.target, LocalInactivityReminderService.reminderPayload);
    expect(opened.metadata, {'source': 'local_inactivity'});
    await tracker.endSession();
    tracker.dispose();
    service.dispose();
  });

  test('denied notification permission does not schedule a reminder', () async {
    final gateway = _FakeGateway(permissionGranted: false);
    final service = _service(gateway);

    await service.start();

    expect(gateway.pending, isEmpty);
    expect(gateway.cancelCalls, isEmpty);
    service.dispose();
  });
}

LocalInactivityReminderService _service(
  _FakeGateway gateway, {
  DateTime Function()? now,
  Duration delay = const Duration(hours: 24),
}) => LocalInactivityReminderService(
  ActivityTracker(FakeActivityRepository()),
  gateway: gateway,
  delay: delay,
  now: now,
);

final class _FakeGateway implements LocalNotificationGateway {
  _FakeGateway({this.permissionGranted = true, this.initialPayload});

  final bool permissionGranted;
  final String? initialPayload;
  final Map<int, DateTime> pending = {};
  final List<int> cancelCalls = [];
  int permissionRequests = 0;

  @override
  Future<bool> initialize(void Function(String? payload) onTap) async {
    if (initialPayload != null) onTap(initialPayload);
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls.add(id);
    pending.remove(id);
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime scheduledAtUtc,
  }) async {
    pending[id] = scheduledAtUtc;
  }
}
