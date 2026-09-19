import 'package:asli_app/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release API URL requires HTTPS and rejects emulator loopback', () {
    expect(
      () => resolveApiBaseUrl(
        configuredUrl: 'http://10.0.2.2:5218',
        releaseMode: true,
        platform: TargetPlatform.android,
      ),
      throwsStateError,
    );
    expect(
      () => resolveApiBaseUrl(
        configuredUrl: 'http://api.example.com',
        releaseMode: true,
        platform: TargetPlatform.android,
      ),
      throwsStateError,
    );
    expect(
      resolveApiBaseUrl(
        configuredUrl: 'https://api.example.com',
        releaseMode: true,
        platform: TargetPlatform.android,
      ),
      'https://api.example.com',
    );
  });

  test('debug API URL keeps the Android emulator default', () {
    expect(
      resolveApiBaseUrl(
        configuredUrl: '',
        releaseMode: false,
        platform: TargetPlatform.android,
      ),
      'http://10.0.2.2:5218',
    );
  });
}
