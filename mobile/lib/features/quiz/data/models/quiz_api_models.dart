import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_answer.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_question.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_submission_result.dart';

final class StudentQuizResponse {
  const StudentQuizResponse({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.questions,
  });

  factory StudentQuizResponse.fromJson(Map<String, dynamic> json) {
    return StudentQuizResponse(
      id: json['id'] as String,
      lessonId: json['lessonId'] as String,
      title: json['title'] as String,
      questions: (json['questions'] as List<dynamic>)
          .map(
            (item) => StudentQuizQuestionResponse.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String lessonId;
  final String title;
  final List<StudentQuizQuestionResponse> questions;

  Quiz toDomain() => Quiz(
    id: id,
    lessonId: lessonId,
    title: title,
    questions: questions.map((question) => question.toDomain()).toList(),
  );
}

final class StudentQuizQuestionResponse {
  const StudentQuizQuestionResponse({
    required this.id,
    required this.prompt,
    required this.options,
  });

  factory StudentQuizQuestionResponse.fromJson(Map<String, dynamic> json) {
    return StudentQuizQuestionResponse(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      options: (json['options'] as List<dynamic>)
          .map(
            (item) => StudentQuizOptionResponse.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String prompt;
  final List<StudentQuizOptionResponse> options;

  QuizQuestion toDomain() => QuizQuestion(
    id: id,
    prompt: prompt,
    options: options.map((option) => option.toDomain()).toList(),
  );
}

final class StudentQuizOptionResponse {
  const StudentQuizOptionResponse({required this.id, required this.text});

  factory StudentQuizOptionResponse.fromJson(Map<String, dynamic> json) {
    return StudentQuizOptionResponse(
      id: json['id'] as String,
      text: json['text'] as String,
    );
  }

  final String id;
  final String text;

  QuizOption toDomain() => QuizOption(id: id, text: text);
}

final class QuizSubmissionRequest {
  const QuizSubmissionRequest(this.answers);

  final List<QuizAnswer> answers;

  Map<String, Object> toJson() => {
    'answers': [
      for (final answer in answers)
        {
          'questionId': answer.questionId,
          'selectedOptionId': answer.selectedOptionId,
        },
    ],
  };
}

final class QuizSubmissionResponse {
  const QuizSubmissionResponse({
    required this.attemptId,
    required this.quizId,
    required this.totalQuestionCount,
    required this.correctCount,
    required this.incorrectCount,
    required this.successPercentage,
    required this.completedAtUtc,
  });

  factory QuizSubmissionResponse.fromJson(Map<String, dynamic> json) {
    return QuizSubmissionResponse(
      attemptId: json['attemptId'] as String,
      quizId: json['quizId'] as String,
      totalQuestionCount: json['totalQuestionCount'] as int,
      correctCount: json['correctCount'] as int,
      incorrectCount: json['incorrectCount'] as int,
      successPercentage: (json['successPercentage'] as num).round(),
      completedAtUtc: DateTime.parse(json['completedAtUtc'] as String),
    );
  }

  final String attemptId;
  final String quizId;
  final int totalQuestionCount;
  final int correctCount;
  final int incorrectCount;
  final int successPercentage;
  final DateTime completedAtUtc;

  QuizSubmissionResult toDomain() => QuizSubmissionResult(
    attemptId: attemptId,
    quizId: quizId,
    totalQuestionCount: totalQuestionCount,
    correctCount: correctCount,
    incorrectCount: incorrectCount,
    successPercentage: successPercentage,
    completedAtUtc: completedAtUtc,
  );
}
