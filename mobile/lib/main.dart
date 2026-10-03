import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/app/app.dart';
import 'package:asli_app/features/notifications/application/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asli_app/app/theme/theme_mode_controller.dart';
import 'package:asli_app/core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fail before initializing services when a release has no valid API endpoint.
  AppConfig.apiBaseUrl;
  final preferences = await SharedPreferences.getInstance();
  if (await initializeFirebaseSafely()) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const App(),
    ),
  );
}
