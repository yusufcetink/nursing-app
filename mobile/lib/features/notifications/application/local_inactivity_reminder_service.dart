import 'dart:async';

import 'package:asli_app/core/config/app_config.dart';
import 'package:asli_app/features/analytics/application/activity_tracker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final localInactivityReminderServiceProvider =
    Provider<LocalInactivityReminderService>((ref) {
      final service = LocalInactivityReminderService(
        ref.watch(activityTrackerProvider),
        gateway: FlutterLocalNotificationGateway(),
        delay: AppConfig.inactivityReminderDelay,
      );
      ref.onDispose(service.dispose);
      return service;
    });

abstract interface class LocalNotificationGateway {
  Future<bool> initialize(void Function(String? payload) onTap);
  Future<bool> requestPermission();
  Future<void> cancel(int id);
  Future<void> schedule({required int id, required DateTime scheduledAtUtc});
}

final class FlutterLocalNotificationGateway
    implements LocalNotificationGateway {
  FlutterLocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _payload = 'local_inactivity_reminder';
  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<bool> initialize(void Function(String? payload) onTap) async {
    tz_data.initializeTimeZones();
    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      onTap(launch?.notificationResponse?.payload);
    }
    return initialized ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> schedule({required int id, required DateTime scheduledAtUtc}) =>
      _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(scheduledAtUtc.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'inactivity_reminder',
            'Öğrenme hatırlatmaları',
            channelDescription: 'Uygulamaya geri dönme hatırlatmaları',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Aslı App seni bekliyor 👋',
        body: 'Kısa bir dersle kaldığın yerden devam etmeye ne dersin?',
        payload: _payload,
      );
}

final class LocalInactivityReminderService with WidgetsBindingObserver {
  LocalInactivityReminderService(
    this._tracker, {
    required this.gateway,
    required this.delay,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const reminderId = 2401;
  static const reminderPayload = 'local_inactivity_reminder';

  final ActivityTracker _tracker;
  final LocalNotificationGateway gateway;
  final Duration delay;
  final DateTime Function() _now;
  Future<void> _pendingOperation = Future<void>.value();
  bool _started = false;
  bool _permissionGranted = false;
  bool _pendingOpenedEvent = false;

  Future<void> start() {
    if (_started) return _pendingOperation;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    return _enqueue(() async {
      try {
        if (!await gateway.initialize(_notificationTapped)) return;
        _permissionGranted = await gateway.requestPermission();
        if (_permissionGranted) await _resetReminder();
      } on Object catch (error) {
        _debug('initialization failed (${error.runtimeType})');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_permissionGranted) return;
    unawaited(
      _enqueue(() async {
        try {
          await _resetReminder();
        } on Object catch (error) {
          _debug('reschedule failed (${error.runtimeType})');
        }
      }),
    );
  }

  void flushPendingOpenedEvent() {
    if (!_pendingOpenedEvent || !_tracker.hasSession) return;
    _pendingOpenedEvent = false;
    _trackOpened();
  }

  Future<void> waitForPendingOperations() => _pendingOperation;

  void dispose() {
    if (_started) WidgetsBinding.instance.removeObserver(this);
  }

  Future<void> _resetReminder() async {
    await gateway.cancel(reminderId);
    await gateway.schedule(
      id: reminderId,
      scheduledAtUtc: _now().toUtc().add(delay),
    );
    _debug('reminder scheduled');
  }

  void _notificationTapped(String? payload) {
    if (payload != reminderPayload) return;
    if (_tracker.hasSession) {
      _trackOpened();
    } else {
      _pendingOpenedEvent = true;
    }
  }

  void _trackOpened() {
    _tracker.track(
      'notification_opened',
      target: reminderPayload,
      metadata: const {'source': 'local_inactivity'},
    );
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    _pendingOperation = _pendingOperation.then((_) => operation());
    return _pendingOperation;
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('[local-reminder] $message');
  }
}
