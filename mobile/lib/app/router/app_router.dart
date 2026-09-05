import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:asli_app/app/shell/app_shell.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:asli_app/features/auth/presentation/pages/email_verification_page.dart';
import 'package:asli_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:asli_app/features/auth/presentation/pages/login_page.dart';
import 'package:asli_app/features/auth/presentation/pages/register_page.dart';
import 'package:asli_app/features/auth/presentation/pages/reset_password_page.dart';
import 'package:asli_app/features/auth/presentation/pages/startup_page.dart';
import 'package:asli_app/features/education/presentation/pages/education_module_page.dart';
import 'package:asli_app/features/education/presentation/pages/lesson_page.dart';
import 'package:asli_app/features/home/presentation/pages/home_page.dart';
import 'package:asli_app/features/profile/presentation/pages/profile_page.dart';
import 'package:asli_app/features/profile/presentation/pages/quiz_history_page.dart';
import 'package:asli_app/features/profile/presentation/pages/quiz_result_detail_page.dart';
import 'package:asli_app/features/quiz/presentation/pages/quiz_page.dart';

abstract final class AppRoutes {
  static const startup = 'startup';
  static const startupPath = '/startup';
  static const login = 'login';
  static const loginPath = '/login';
  static const register = 'register';
  static const registerPath = '/register';
  static const forgotPassword = 'forgot-password';
  static const forgotPasswordPath = '/forgot-password';
  static const emailVerification = 'email-verification';
  static const emailVerificationPath = '/verify-email';
  static const resetPassword = 'reset-password';
  static const resetPasswordPath = '/reset-password';
  static const home = 'home';
  static const homePath = '/home';
  static const profile = 'profile';
  static const profilePath = '/profile';
  static const quizHistory = 'quiz-history';
  static const quizHistoryPath = '/profile/quiz-history';
  static const quizResultDetail = 'quiz-result-detail';
  static const quizResultDetailPath = '/profile/quiz-history/:attemptId';
  static const attemptIdParameter = 'attemptId';
  static const educationModule = 'education-module';
  static const educationModulePath = '/education/:moduleId';
  static const moduleIdParameter = 'moduleId';
  static const lesson = 'lesson';
  static const lessonPath = '/education/:moduleId/lessons/:lessonId';
  static const lessonIdParameter = 'lessonId';
  static const quiz = 'quiz';
  static const quizPath = '/education/:moduleId/lessons/:lessonId/quiz';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh();
  ref
    ..onDispose(refresh.dispose)
    ..listen(authControllerProvider, (_, _) => refresh.notify());

  return GoRouter(
    initialLocation: AppRoutes.startupPath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      if (!authState.hasValue) {
        return location == AppRoutes.startupPath ||
                _publicAuthPaths.contains(location)
            ? null
            : AppRoutes.startupPath;
      }

      final isAuthRoute = _authPaths.contains(location);
      if (authState.value == null) {
        return _publicAuthPaths.contains(location) ? null : AppRoutes.loginPath;
      }
      return isAuthRoute ? AppRoutes.homePath : null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.startupPath,
        name: AppRoutes.startup,
        builder: (context, state) => const StartupPage(),
      ),
      GoRoute(
        path: AppRoutes.loginPath,
        name: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.registerPath,
        name: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPasswordPath,
        name: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.emailVerificationPath,
        name: AppRoutes.emailVerification,
        builder: (context, state) => EmailVerificationPage(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPasswordPath,
        name: AppRoutes.resetPassword,
        builder: (context, state) => ResetPasswordPage(
          initialEmail: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.homePath,
                name: AppRoutes.home,
                builder: (context, state) => const HomePage(),
              ),
              GoRoute(
                path: AppRoutes.educationModulePath,
                name: AppRoutes.educationModule,
                builder: (context, state) => EducationModulePage(
                  moduleId: state.pathParameters[AppRoutes.moduleIdParameter]!,
                ),
              ),
              GoRoute(
                path: AppRoutes.lessonPath,
                name: AppRoutes.lesson,
                builder: (context, state) => LessonPage(
                  moduleId: state.pathParameters[AppRoutes.moduleIdParameter]!,
                  lessonId: state.pathParameters[AppRoutes.lessonIdParameter]!,
                ),
              ),
              GoRoute(
                path: AppRoutes.quizPath,
                name: AppRoutes.quiz,
                builder: (context, state) => QuizPage(
                  moduleId: state.pathParameters[AppRoutes.moduleIdParameter]!,
                  lessonId: state.pathParameters[AppRoutes.lessonIdParameter]!,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profilePath,
                name: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
              ),
              GoRoute(
                path: AppRoutes.quizHistoryPath,
                name: AppRoutes.quizHistory,
                builder: (context, state) => const QuizHistoryPage(),
              ),
              GoRoute(
                path: AppRoutes.quizResultDetailPath,
                name: AppRoutes.quizResultDetail,
                builder: (context, state) => QuizResultDetailPage(
                  attemptId:
                      state.pathParameters[AppRoutes.attemptIdParameter]!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

const _authPaths = {
  AppRoutes.startupPath,
  AppRoutes.loginPath,
  AppRoutes.registerPath,
  AppRoutes.forgotPasswordPath,
  AppRoutes.emailVerificationPath,
  AppRoutes.resetPasswordPath,
};

const _publicAuthPaths = {
  AppRoutes.loginPath,
  AppRoutes.registerPath,
  AppRoutes.forgotPasswordPath,
  AppRoutes.emailVerificationPath,
  AppRoutes.resetPasswordPath,
};

final class _AuthRouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
