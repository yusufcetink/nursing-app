final class QuizSubmissionResult {
  const QuizSubmissionResult({
    required this.attemptId,
    required this.quizId,
    required this.totalQuestionCount,
    required this.correctCount,
    required this.incorrectCount,
    required this.successPercentage,
    required this.completedAtUtc,
  });

  final String attemptId;
  final String quizId;
  final int totalQuestionCount;
  final int correctCount;
  final int incorrectCount;
  final int successPercentage;
  final DateTime completedAtUtc;
}
