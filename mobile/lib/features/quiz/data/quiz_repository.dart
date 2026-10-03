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
  Future<Quiz> getQuiz(String quizId);
  Future<Quiz> getQuizAttempt(String quizId);
  Future<Quiz> startQuiz(String quizId);
  Future<Quiz> saveAnswer(String attemptId, QuizAnswer answer);
}

final class DioQuizRepository implements QuizRepository {
  const DioQuizRepository(this._apiClient);
  final ApiClient _apiClient;
  @override
  Future<Quiz> getQuiz(String quizId) =>
      _request('/api/education/quizzes/$quizId', attempt: false);
  @override
  Future<Quiz> getQuizAttempt(String quizId) =>
      _request('/api/education/quizzes/$quizId/attempt');
  @override
  Future<Quiz> startQuiz(String quizId) =>
      _request('/api/education/quizzes/$quizId/start', post: true);
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
      if (error.response?.statusCode == 403 &&
          error.response?.data is Map &&
          error.response?.data['code'] == 'lesson_not_completed') {
        throw const NetworkException('Quizi açmak için önce dersi tamamla.');
      }
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Sunucudan geçersiz quiz verisi alındı.');
    } on TypeError {
      throw const NetworkException('Sunucudan geçersiz quiz verisi alındı.');
    }
  }
}
