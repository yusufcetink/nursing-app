import 'package:asli_app/features/profile/domain/models/profile_overview.dart';

final class QuizHistoryResponse {
  const QuizHistoryResponse({
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

  factory QuizHistoryResponse.fromJson(Map<String, dynamic> json) {
    return QuizHistoryResponse(
      attemptId: json['attemptId'] as String,
      quizId: json['quizId'] as String,
      lessonId: json['lessonId'] as String,
      quizTitle: json['quizTitle'] as String,
      lessonTitle: json['lessonTitle'] as String,
      totalQuestionCount: json['totalQuestionCount'] as int,
      correctCount: json['correctCount'] as int,
      incorrectCount: json['incorrectCount'] as int,
      successPercentage: (json['successPercentage'] as num).round(),
      completedAtUtc: DateTime.parse(json['completedAtUtc'] as String),
    );
  }

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

  ProfileQuizResult toDomain() => ProfileQuizResult(
    attemptId: attemptId,
    quizId: quizId,
    lessonId: lessonId,
    quizTitle: quizTitle,
    lessonTitle: lessonTitle,
    totalQuestionCount: totalQuestionCount,
    correctCount: correctCount,
    incorrectCount: incorrectCount,
    successPercentage: successPercentage,
    completedAtUtc: completedAtUtc,
  );
}
