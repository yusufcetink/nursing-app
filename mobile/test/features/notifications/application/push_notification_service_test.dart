import 'dart:async';
import 'dart:convert';

import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/features/analytics/application/activity_tracker.dart';
import 'package:asli_app/features/notifications/application/push_notification_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_activity_repository.dart';

void main() {
  test('registers after permission and updates the refreshed token', () async {
    final adapter = _RecordingAdapter();
    final gateway = _FakeGateway(token: 'initial-token');
    final store = _MemoryStore();
    final service = _service(adapter, gateway, store);

    await service.activate(navigate: (_) {});
    gateway.tokenRefresh.add('refreshed-token');
    await _waitFor(() => adapter.requests.length == 2);

    expect(adapter.requests, hasLength(2));
    expect(adapter.requests[0].method, 'PUT');
    expect(adapter.requests[0].path, '/api/devices/current');
    expect(adapter.requests[0].data, {
      'installationId': 'firebase-installation',
      'deviceToken': 'initial-token',
      'platform': 'android',
      'notificationsEnabled': true,
    });
    expect(adapter.requests[1].data['deviceToken'], 'refreshed-token');
    expect(gateway.permissionRequests, 1);
    expect(gateway.installationRequests, 1);

    await service.deactivate();
    await gateway.close();
  });

  test(
    'logout deactivates the stored installation and stops refresh',
    () async {
      final adapter = _RecordingAdapter();
      final gateway = _FakeGateway(token: 'token');
      final service = _service(
        adapter,
        gateway,
        _MemoryStore(value: 'stored-installation'),
      );
      await service.activate(navigate: (_) {});

      await service.deactivate();
      gateway.tokenRefresh.add('late-token');
      await _settle();

      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.method, 'POST');
      expect(adapter.requests.last.path, '/api/devices/current/deactivate');
      expect(adapter.requests.last.data, {
        'installationId': 'stored-installation',
      });
      await gateway.close();
    },
  );

  test('denied permission deactivates an earlier registration', () async {
    final adapter = _RecordingAdapter();
    final gateway = _FakeGateway(
      token: 'must-not-be-read',
      permission: PushPermission.disabled,
    );
    final service = _service(
      adapter,
      gateway,
      _MemoryStore(value: 'stored-installation'),
    );

    await service.activate(navigate: (_) {});

    expect(gateway.tokenRequests, 0);
    expect(adapter.requests.single.path, '/api/devices/current/deactivate');
    await service.deactivate();
    await gateway.close();
  });

  test(
    'notification open is deduplicated, tracked, acknowledged and routed',
    () async {
      final adapter = _RecordingAdapter();
      final notificationId = '123e4567-e89b-42d3-a456-426614174000';
      final opened = PushOpenedMessage(
        messageId: 'message-1',
        data: {
          'notificationId': notificationId,
          'type': 'inactivity_reminder',
          'route': '/profile',
        },
      );
      final gateway = _FakeGateway(token: 'token', initialMessage: opened);
      final repository = FakeActivityRepository();
      final tracker = ActivityTracker(
        repository,
        flushInterval: const Duration(days: 1),
      )..startSession();
      final routes = <String>[];
      final service = _service(
        adapter,
        gateway,
        _MemoryStore(),
        tracker: tracker,
      );

      await service.activate(navigate: routes.add);
      gateway.openedMessages.add(opened);
      await _waitFor(
        () => adapter.requests.any(
          (request) =>
              request.path == '/api/notifications/$notificationId/opened',
        ),
      );
      await tracker.flush();

      expect(routes, ['/profile']);
      expect(
        repository.events.where(
          (event) => event.eventType == 'notification_opened',
        ),
        hasLength(1),
      );
      expect(
        adapter.requests.where(
          (request) =>
              request.path == '/api/notifications/$notificationId/opened',
        ),
        hasLength(1),
      );

      await service.deactivate();
      await tracker.endSession();
      tracker.dispose();
      await gateway.close();
    },
  );
}

PushNotificationService _service(
  _RecordingAdapter adapter,
  _FakeGateway gateway,
  _MemoryStore store, {
  ActivityTracker? tracker,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://example.test'))
    ..httpClientAdapter = adapter;
  return PushNotificationService(
    ApiClient(dio: dio),
    tracker ?? ActivityTracker(FakeActivityRepository()),
    gateway: gateway,
    store: store,
    platform: TargetPlatform.android,
  );
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

final class _FakeGateway implements PushMessagingGateway {
  _FakeGateway({
    required this.token,
    this.permission = PushPermission.enabled,
    this.initialMessage,
  });

  final String? token;
  final PushPermission permission;
  final PushOpenedMessage? initialMessage;
  final tokenRefresh = StreamController<String>.broadcast();
  final openedMessages = StreamController<PushOpenedMessage>.broadcast();
  int permissionRequests = 0;
  int tokenRequests = 0;
  int installationRequests = 0;

  @override
  Future<String> getInstallationId() async {
    installationRequests++;
    return 'firebase-installation';
  }

  @override
  Future<PushOpenedMessage?> getInitialMessage() async => initialMessage;

  @override
  Future<String?> getToken() async {
    tokenRequests++;
    return token;
  }

  @override
  Stream<PushOpenedMessage> get onMessageOpenedApp => openedMessages.stream;

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Future<PushPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  Future<void> close() async {
    await tokenRefresh.close();
    await openedMessages.close();
  }
}

final class _MemoryStore implements PushDeviceStore {
  _MemoryStore({this.value});
  String? value;

  @override
  Future<String?> readInstallationId() async => value;

  @override
  Future<void> writeInstallationId(String value) async => this.value = value;
}

final class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({}),
      options.method == 'POST' ? 204 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
