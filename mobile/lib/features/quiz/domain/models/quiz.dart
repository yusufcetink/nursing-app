import 'package:asli_app/features/quiz/domain/models/quiz_question.dart';

final class Quiz {
  Quiz({
    required this.id,
    required this.lessonId,
    required this.title,
    required List<QuizQuestion> questions,
  }) : assert(questions.isNotEmpty),
       questions = List.unmodifiable(questions);

  final String id;
  final String lessonId;
  final String title;
  final List<QuizQuestion> questions;
}
