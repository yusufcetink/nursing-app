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
import 'package:asli_app/features/content_management/presentation/pages/content_module_detail_page.dart';
import 'package:asli_app/features/content_management/presentation/pages/content_modules_page.dart';
import 'package:asli_app/features/content_management/presentation/pages/lesson_form_page.dart';
import 'package:asli_app/features/content_management/presentation/pages/module_form_page.dart';
import 'package:asli_app/features/content_management/presentation/pages/question_form_page.dart';
import 'package:asli_app/features/content_management/presentation/pages/quiz_editor_page.dart';
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
  static const content = 'content';
  static const contentPath = '/content';
  static const contentModuleCreate = 'content-module-create';
  static const contentModuleCreatePath = '/content/modules/new';
  static const contentModule = 'content-module';
  static const contentModulePath = '/content/modules/:contentModuleId';
  static const contentModuleEdit = 'content-module-edit';
  static const contentModuleEditPath = '/content/modules/:contentModuleId/edit';
  static const contentLessonCreate = 'content-lesson-create';
  static const contentLessonCreatePath =
      '/content/modules/:contentModuleId/lessons/new';
  static const contentLessonEdit = 'content-lesson-edit';
  static const contentLessonEditPath =
      '/content/modules/:contentModuleId/lessons/:contentLessonId/edit';
  static const contentModuleIdParameter = 'contentModuleId';
  static const contentLessonIdParameter = 'contentLessonId';
  static const contentQuiz = 'content-quiz';
  static const contentQuizPath =
      '/content/modules/:contentModuleId/lessons/:contentLessonId/quiz';
  static const contentQuestionCreate = 'content-question-create';
  static const contentQuestionCreatePath =
      '/content/modules/:contentModuleId/lessons/:contentLessonId/quiz/:contentQuizId/questions/new';
  static const contentQuestionEdit = 'content-question-edit';
  static const contentQuestionEditPath =
      '/content/modules/:contentModuleId/lessons/:contentLessonId/quiz/:contentQuizId/questions/:contentQuestionId/edit';
  static const contentQuizIdParameter = 'contentQuizId';
  static const contentQuestionIdParameter = 'contentQuestionId';
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
      if (location.startsWith(AppRoutes.contentPath) &&
          !authState.value!.canManageContent) {
        return AppRoutes.homePath;
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
                path: AppRoutes.contentPath,
                name: AppRoutes.content,
                builder: (context, state) => const ContentModulesPage(),
              ),
              GoRoute(
                path: AppRoutes.contentModuleCreatePath,
                name: AppRoutes.contentModuleCreate,
                builder: (context, state) => const ModuleFormPage(),
              ),
              GoRoute(
                path: AppRoutes.contentModuleEditPath,
                name: AppRoutes.contentModuleEdit,
                builder: (context, state) => ModuleFormPage(
                  moduleId:
                      state.pathParameters[AppRoutes.contentModuleIdParameter]!,
                ),
              ),
              GoRoute(
                path: AppRoutes.contentLessonCreatePath,
                name: AppRoutes.contentLessonCreate,
                builder: (context, state) => LessonFormPage(
                  moduleId:
                      state.pathParameters[AppRoutes.contentModuleIdParameter]!,
                ),
              ),
              GoRoute(
                path: AppRoutes.contentLessonEditPath,
                name: AppRoutes.contentLessonEdit,
                builder: (context, state) => LessonFormPage(
                  moduleId:
                      state.pathParameters[AppRoutes.contentModuleIdParameter]!,
                  lessonId:
                      state.pathParameters[AppRoutes.contentLessonIdParameter]!,
                ),
              ),
              GoRoute(
                path: AppRoutes.contentQuizPath,
                name: AppRoutes.contentQuiz,
                builder: (context, state) => QuizEditorPage(
                  moduleId:
                      state.pathParameters[AppRoutes.contentModuleIdParameter]!,
                  lessonId:
                      state.pathParameters[AppRoutes.contentLessonIdParameter]!,
                ),
              ),
              GoRoute(
                path: AppRoutes.contentQuestionCreatePath,
                name: AppRoutes.contentQuestionCreate,
                builder: (context, state) => QuestionFormPage(
                  lessonId:
                      state.pathParameters[AppRoutes.contentLessonIdParameter]!,
                  quizId:
                      state.pathParameters[AppRoutes.contentQuizIdParameter]!,
                ),
              ),
              GoRoute(
                path: AppRoutes.contentQuestionEditPath,
                name: AppRoutes.contentQuestionEdit,
                builder: (context, state) => QuestionFormPage(
                  lessonId:
                      state.pathParameters[AppRoutes.contentLessonIdParameter]!,
                  quizId:
                      state.pathParameters[AppRoutes.contentQuizIdParameter]!,
                  questionId: state
                      .pathParameters[AppRoutes.contentQuestionIdParameter]!,
                ),
              ),
              GoRoute(
                path: AppRoutes.contentModulePath,
                name: AppRoutes.contentModule,
                builder: (context, state) => ContentModuleDetailPage(
                  moduleId:
                      state.pathParameters[AppRoutes.contentModuleIdParameter]!,
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
