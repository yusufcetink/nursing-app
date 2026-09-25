import 'package:asli_app/features/quiz/domain/models/quiz_question.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_answer.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_submission_result.dart';

final class Quiz {
  Quiz({
    required this.id,
    required this.lessonId,
    required this.title,
    required List<QuizQuestion> questions,
    this.attemptId,
    this.status = 'NotStarted',
    this.savedAnswers = const [],
    this.result,
  }) : assert(questions.isNotEmpty),
       questions = List.unmodifiable(questions);

  final String id;
  final String lessonId;
  final String title;
  final List<QuizQuestion> questions;
  final String? attemptId;
  final String status;
  final List<QuizAnswer> savedAnswers;
  final QuizSubmissionResult? result;
}
