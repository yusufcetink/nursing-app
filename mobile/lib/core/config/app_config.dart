import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) {
      return _configuredApiBaseUrl;
    }
    if (kReleaseMode) {
      throw StateError('API_BASE_URL must be configured for release builds.');
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5218';
    }
    return 'http://127.0.0.1:5218';
  }
}
