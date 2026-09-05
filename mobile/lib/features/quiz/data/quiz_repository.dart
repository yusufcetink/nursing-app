import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/quiz/data/models/quiz_api_models.dart';
import 'package:asli_app/features/quiz/domain/models/quiz.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_answer.dart';
import 'package:asli_app/features/quiz/domain/models/quiz_submission_result.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return DioQuizRepository(ref.watch(apiClientProvider));
});

abstract interface class QuizRepository {
  Future<Quiz> getLessonQuiz(String lessonId);

  Future<QuizSubmissionResult> submitLessonQuiz(
    String lessonId,
    List<QuizAnswer> answers,
  );
}

final class DioQuizRepository implements QuizRepository {
  const DioQuizRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Quiz> getLessonQuiz(String lessonId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/education/lessons/$lessonId/quiz',
      );
      final data = response.data;
      if (data == null) throw const FormatException();
      return StudentQuizResponse.fromJson(data).toDomain();
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Sunucudan geçersiz quiz verisi alındı.');
    } on TypeError {
      throw const NetworkException('Sunucudan geçersiz quiz verisi alındı.');
    }
  }

  @override
  Future<QuizSubmissionResult> submitLessonQuiz(
    String lessonId,
    List<QuizAnswer> answers,
  ) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/education/lessons/$lessonId/quiz/submit',
        data: QuizSubmissionRequest(answers).toJson(),
      );
      final data = response.data;
      if (data == null) throw const FormatException();
      return QuizSubmissionResponse.fromJson(data).toDomain();
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Sunucudan geçersiz quiz sonucu alındı.');
    } on TypeError {
      throw const NetworkException('Sunucudan geçersiz quiz sonucu alındı.');
    }
  }
}
