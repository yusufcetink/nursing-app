import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const productionApiBaseUrl = 'https://api.nursing-app.com';
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
      return AppConfig.productionApiBaseUrl;
    }
    return platform == TargetPlatform.android
        ? 'http://10.0.2.2:5218'
        : 'http://127.0.0.1:5218';
  }

  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasScheme ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw StateError('API_BASE_URL must be an absolute URL.');
  }

  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  final ipv4 = host.split('.');
  final isLoopback =
      host == 'localhost' ||
      host.endsWith('.localhost') ||
      (ipv4.length == 4 && ipv4.first == '127') ||
      host == '0.0.0.0' ||
      host == '::' ||
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
