import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/quiz/data/models/quiz_api_models.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_answer.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return DioQuizRepository(ref.watch(apiClientProvider));
});

abstract interface class QuizRepository {
  Future<Quiz> getLessonQuiz(String lessonId);
  Future<Quiz> getLessonAttempt(String lessonId);
  Future<Quiz> startLessonQuiz(String lessonId);
  Future<Quiz> saveAnswer(String attemptId, QuizAnswer answer);
}

final class DioQuizRepository implements QuizRepository {
  const DioQuizRepository(this._apiClient);
  final ApiClient _apiClient;
  @override
  Future<Quiz> getLessonQuiz(String lessonId) =>
      _request('/api/education/lessons/$lessonId/quiz', attempt: false);
  @override
  Future<Quiz> getLessonAttempt(String lessonId) =>
      _request('/api/education/lessons/$lessonId/quiz/attempt');
  @override
  Future<Quiz> startLessonQuiz(String lessonId) =>
      _request('/api/education/lessons/$lessonId/quiz/start', post: true);
  @override
  Future<Quiz> saveAnswer(String attemptId, QuizAnswer answer) => _request(
    '/api/education/quiz-attempts/$attemptId/answers',
    post: true,
    data: {
      'questionId': answer.questionId,
      'selectedOptionId': answer.selectedOptionId,
    },
  );

  Future<Quiz> _request(
    String path, {
    bool post = false,
    bool attempt = true,
    Object? data,
  }) async {
    try {
      final response = post
          ? await _apiClient.dio.post<Map<String, dynamic>>(path, data: data)
          : await _apiClient.dio.get<Map<String, dynamic>>(path);
      final json = response.data;
      if (json == null) throw const FormatException();
      if (!attempt) return StudentQuizResponse.fromJson(json).toDomain();
      final quiz = StudentQuizResponse.fromJson(
        json['quiz'] as Map<String, dynamic>,
      ).toDomain();
      final status = json['status'] as String;
      if (!['NotStarted', 'InProgress', 'Completed'].contains(status)) {
        throw const FormatException();
      }
      final answers = (json['answers'] as List<dynamic>)
          .map(
            (item) => QuizAnswer(
              questionId: item['questionId'] as String,
              selectedOptionId: item['selectedOptionId'] as String,
            ),
          )
          .toList();
      final resultJson = json['result'];
      if (status != 'NotStarted' && json['attemptId'] == null ||
          status == 'Completed' && resultJson == null) {
        throw const FormatException();
      }
      return Quiz(
        id: quiz.id,
        lessonId: quiz.lessonId,
        title: quiz.title,
        questions: quiz.questions,
        attemptId: json['attemptId'] as String?,
        status: status,
        savedAnswers: List.unmodifiable(answers),
        result: resultJson == null
            ? null
            : QuizSubmissionResponse.fromJson(
                resultJson as Map<String, dynamic>,
              ).toDomain(),
      );
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Sunucudan geçersiz quiz verisi alındı.');
    } on TypeError {
      throw const NetworkException('Sunucudan geçersiz quiz verisi alındı.');
    }
  }
}
