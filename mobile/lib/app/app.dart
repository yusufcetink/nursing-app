import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/app/router/app_router.dart';
import 'package:asli_app/app/theme/app_theme.dart';
import 'package:asli_app/features/analytics/application/activity_tracker.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/notifications/application/push_notification_service.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final ActivityTracker _tracker;
  late final bool _servicesEnabled;

  @override
  void initState() {
    super.initState();
    _tracker = ref.read(activityTrackerProvider);
    _servicesEnabled = !WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
    WidgetsBinding.instance.addObserver(_tracker);
    ref.listenManual(authControllerProvider, (previous, next) {
      if (next.isLoading || next.hasError) return;
      final authenticated = next.hasValue && next.value != null;
      if (authenticated) {
        _tracker.startSession();
        final router = ref.read(appRouterProvider);
        if (_servicesEnabled) {
          unawaited(
            ref
                .read(pushNotificationServiceProvider)
                .activate(navigate: router.go),
          );
        }
      } else if (previous?.value != null) {
        unawaited(_tracker.endSession());
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_tracker);
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Aslı App',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(appRouterProvider),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
    );
  }
}
