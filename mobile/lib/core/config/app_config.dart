import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _configuredInactivityMinutes = int.fromEnvironment(
    'INACTIVITY_REMINDER_MINUTES',
  );

  static Duration get inactivityReminderDelay => resolveInactivityReminderDelay(
    releaseMode: kReleaseMode,
    developmentMinutes: _configuredInactivityMinutes,
  );

  static String get apiBaseUrl {
    return resolveApiBaseUrl(
      configuredUrl: _configuredApiBaseUrl,
      releaseMode: kReleaseMode,
      platform: defaultTargetPlatform,
    );
  }
}

String resolveApiBaseUrl({
  required String configuredUrl,
  required bool releaseMode,
  required TargetPlatform platform,
}) {
  final value = configuredUrl.trim();
  if (value.isEmpty) {
    if (releaseMode) {
      throw StateError('API_BASE_URL must be configured for release builds.');
    }
    return platform == TargetPlatform.android
        ? 'http://10.0.2.2:5218'
        : 'http://127.0.0.1:5218';
  }

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    throw StateError('API_BASE_URL must be an absolute URL.');
  }

  final host = uri.host.toLowerCase();
  final isLoopback =
      host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '10.0.2.2';
  if (releaseMode && (uri.scheme.toLowerCase() != 'https' || isLoopback)) {
    throw StateError(
      'Release API_BASE_URL must use HTTPS and cannot target a loopback host.',
    );
  }

  return value;
}

Duration resolveInactivityReminderDelay({
  required bool releaseMode,
  required int developmentMinutes,
}) => !releaseMode && developmentMinutes > 0
    ? Duration(minutes: developmentMinutes)
    : const Duration(hours: 24);
