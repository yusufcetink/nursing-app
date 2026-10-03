import 'package:asli_app/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final url in [
    'https://localhost',
    'https://localhost.',
    'https://api.localhost',
    'https://127.0.0.2',
    'https://0.0.0.0',
    'https://[::1]',
    'https://[::]',
    'https://10.0.2.2',
    'https://',
    'https://user:password@api.example.com',
    'https://api.example.com?token=value',
    'https://api.example.com#fragment',
    'ftp://api.example.com',
  ]) {
    test('release rejects invalid API URL: $url', () {
      expect(
        () => resolveApiBaseUrl(
          configuredUrl: url,
          releaseMode: true,
          platform: TargetPlatform.android,
        ),
        throwsStateError,
      );
    });
  }

  test('release defaults to the production API', () {
    expect(
      resolveApiBaseUrl(
        configuredUrl: '',
        releaseMode: true,
        platform: TargetPlatform.android,
      ),
      'https://api.nursing-app.com',
    );
  });

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
