import 'package:asli_app/features/profile/domain/models/profile_user.dart';

final class ProfileQuizResult {
  const ProfileQuizResult({
    required this.attemptId,
    required this.quizId,
    required this.lessonId,
    required this.quizTitle,
    required this.lessonTitle,
    required this.totalQuestionCount,
    required this.correctCount,
    required this.incorrectCount,
    required this.successPercentage,
    required this.completedAtUtc,
  });

  final String attemptId;
  final String quizId;
  final String lessonId;
  final String quizTitle;
  final String lessonTitle;
  final int totalQuestionCount;
  final int correctCount;
  final int incorrectCount;
  final int successPercentage;
  final DateTime completedAtUtc;
}

final class ProfileOverview {
  ProfileOverview({
    required this.user,
    required this.completedLessonCount,
    required List<ProfileQuizResult> quizResults,
  }) : quizResults = List.unmodifiable(quizResults);

  final ProfileUser user;
  final int completedLessonCount;
  final List<ProfileQuizResult> quizResults;

  int get completedQuizCount => quizResults.length;
}
