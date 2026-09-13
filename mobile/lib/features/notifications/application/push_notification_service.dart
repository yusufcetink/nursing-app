import 'dart:async';

import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/features/analytics/application/activity_tracker.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final service = PushNotificationService(
    ref.watch(apiClientProvider),
    ref.watch(activityTrackerProvider),
    gateway: Firebase.apps.isEmpty ? null : FirebasePushMessagingGateway(),
  );
  ref.onDispose(service.dispose);
  return service;
});

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initializeFirebaseSafely();
}

Future<bool> initializeFirebaseSafely() async {
  if (Firebase.apps.isNotEmpty) return true;
  try {
    await Firebase.initializeApp();
    return true;
  } on Object {
    return false;
  }
}

enum PushPermission { enabled, disabled }

final class PushOpenedMessage {
  const PushOpenedMessage({required this.data, this.messageId});
  final Map<String, dynamic> data;
  final String? messageId;
}

abstract interface class PushMessagingGateway {
  Future<PushPermission> requestPermission();
  Future<String?> getToken();
  Future<String> getInstallationId();
  Stream<String> get onTokenRefresh;
  Stream<PushOpenedMessage> get onMessageOpenedApp;
  Future<PushOpenedMessage?> getInitialMessage();
}

final class FirebasePushMessagingGateway implements PushMessagingGateway {
  @override
  Future<PushPermission> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional
        ? PushPermission.enabled
        : PushPermission.disabled;
  }

  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  @override
  Future<String> getInstallationId() => FirebaseInstallations.instance.getId();

  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<PushOpenedMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_message);

  @override
  Future<PushOpenedMessage?> getInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : _message(message);
  }

  static PushOpenedMessage _message(RemoteMessage message) =>
      PushOpenedMessage(data: message.data, messageId: message.messageId);
}

abstract interface class PushDeviceStore {
  Future<String?> readInstallationId();
  Future<void> writeInstallationId(String value);
}

final class SecurePushDeviceStore implements PushDeviceStore {
  SecurePushDeviceStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _installationKey = 'firebase_installation_id';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readInstallationId() => _storage.read(key: _installationKey);

  @override
  Future<void> writeInstallationId(String value) =>
      _storage.write(key: _installationKey, value: value);
}

final class PushNotificationService {
  static const _localStoreTimeout = Duration(seconds: 2);

  PushNotificationService(
    this._apiClient,
    this._tracker, {
    this.gateway,
    PushDeviceStore? store,
    TargetPlatform? platform,
  }) : _store = store ?? SecurePushDeviceStore(),
       _platform = platform ?? defaultTargetPlatform;

  final ApiClient _apiClient;
  final ActivityTracker _tracker;
  final PushMessagingGateway? gateway;
  final PushDeviceStore _store;
  final TargetPlatform _platform;
  final Set<String> _handledMessages = {};
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<PushOpenedMessage>? _openSubscription;
  void Function(String route)? _navigate;

  Future<void> activate({required void Function(String route) navigate}) async {
    _navigate = navigate;
    final messagingGateway = gateway;
    if (messagingGateway == null) return;
    await _tokenSubscription?.cancel();
    await _openSubscription?.cancel();
    _openSubscription = messagingGateway.onMessageOpenedApp.listen(_opened);
    try {
      final permission = await messagingGateway.requestPermission();
      if (permission == PushPermission.disabled) {
        await _deactivateRegistration();
        _debug('permission disabled; registration deactivated');
        return;
      }
      final token = await messagingGateway.getToken();
      if (token == null || token.trim().isEmpty) {
        await _deactivateRegistration();
        _debug('device token unavailable; registration deactivated');
        return;
      }
      await _register(token);
      _tokenSubscription = messagingGateway.onTokenRefresh.listen(
        (refreshedToken) => unawaited(_registerSafely(refreshedToken)),
        onError: (_) => _debug('token refresh stream failed'),
      );
      final initial = await messagingGateway.getInitialMessage();
      if (initial != null) _opened(initial);
    } on Object catch (error) {
      _debug('activation failed (${error.runtimeType})');
    }
  }

  Future<void> deactivate() async {
    try {
      if (gateway != null) await _deactivateRegistration();
    } on Object catch (error) {
      _debug('deactivation failed (${error.runtimeType})');
    } finally {
      await _tokenSubscription?.cancel();
      await _openSubscription?.cancel();
      _tokenSubscription = null;
      _openSubscription = null;
      _navigate = null;
    }
  }

  void dispose() {
    unawaited(_tokenSubscription?.cancel());
    unawaited(_openSubscription?.cancel());
  }

  Future<void> _registerSafely(String token) async {
    try {
      await _register(token);
    } on Object catch (error) {
      _debug('token refresh registration failed (${error.runtimeType})');
    }
  }

  Future<void> _register(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return;
    var installationId = await _store.readInstallationId().timeout(
      _localStoreTimeout,
    );
    if (installationId == null || installationId.trim().isEmpty) {
      installationId = await gateway!.getInstallationId();
      await _store.writeInstallationId(installationId);
    }
    await _apiClient.dio.put<void>(
      '/api/devices/current',
      data: {
        'installationId': installationId,
        'deviceToken': cleanToken,
        'platform': _platform == TargetPlatform.iOS ? 'ios' : 'android',
        'notificationsEnabled': true,
      },
    );
    _debug('device registration updated');
  }

  Future<void> _deactivateRegistration() async {
    final installationId = await _store.readInstallationId().timeout(
      _localStoreTimeout,
    );
    if (installationId == null || installationId.trim().isEmpty) return;
    await _apiClient.dio.post<void>(
      '/api/devices/current/deactivate',
      data: {'installationId': installationId},
    );
  }

  void _opened(PushOpenedMessage message) {
    final notificationId = message.data['notificationId']?.toString();
    final identity = message.messageId ?? notificationId;
    if (identity != null && !_handledMessages.add(identity)) return;
    final route = _safeRoute(message.data['route']);
    _tracker.track(
      'notification_opened',
      target: route,
      metadata: {'source': message.data['type']?.toString() ?? 'push'},
    );
    if (notificationId != null && _guid.hasMatch(notificationId)) {
      unawaited(_markOpenedSafely(notificationId));
    }
    _navigate?.call(route);
  }

  Future<void> _markOpenedSafely(String notificationId) async {
    try {
      await _apiClient.dio.post<void>(
        '/api/notifications/$notificationId/opened',
      );
    } on Object catch (error) {
      _debug('opened acknowledgement failed (${error.runtimeType})');
    }
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('[push] $message');
  }
}

final _guid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

String _safeRoute(Object? value) {
  if (value is! String || value.startsWith('//')) return '/home';
  if (value == '/home' || value == '/profile') return value;
  return value.startsWith('/education/') || value.startsWith('/profile/')
      ? value
      : '/home';
}
