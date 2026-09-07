import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/content_management/data/models/content_management_api_models.dart';
import 'package:asli_app/features/content_management/domain/models/content_models.dart';

final contentManagementRepositoryProvider =
    Provider<ContentManagementRepository>(
      (ref) => DioContentManagementRepository(ref.watch(apiClientProvider)),
    );

abstract interface class ContentManagementRepository {
  Future<List<ContentModuleSummary>> getModules();

  Future<ContentModule> getModule(String id);

  Future<ContentLesson> getLesson(String id);

  Future<ContentQuiz?> getQuizForLesson(String lessonId);

  Future<String> createModule(ModuleWriteInput input);

  Future<void> updateModule(String id, ModuleWriteInput input);

  Future<void> deleteModule(String id);

  Future<String> createLesson(String moduleId, LessonWriteInput input);

  Future<void> updateLesson(String id, LessonWriteInput input);

  Future<void> deleteLesson(String id);

  Future<String> createQuiz(String lessonId, QuizWriteInput input);

  Future<void> updateQuiz(String id, QuizWriteInput input);

  Future<void> deleteQuiz(String id);

  Future<String> createQuestion(String quizId, QuizQuestionWriteInput input);

  Future<void> updateQuestion(String id, QuizQuestionWriteInput input);

  Future<void> deleteQuestion(String id);

  Future<String> createOption(String questionId, QuizOptionWriteInput input);

  Future<void> updateOption(String id, QuizOptionWriteInput input);
}

final class DioContentManagementRepository
    implements ContentManagementRepository {
  const DioContentManagementRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<ContentModuleSummary>> getModules() async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>(
        '/api/education/content/modules',
      );
      return (response.data ?? const [])
          .map(
            (item) => ContentModuleSummaryResponse.fromJson(
              item as Map<String, dynamic>,
            ).toDomain(),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on Object {
      throw const NetworkException('Sunucudan geçersiz modül verisi alındı.');
    }
  }

  @override
  Future<ContentModule> getModule(String id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/education/content/modules/$id',
      );
      final data = response.data;
      if (data == null) throw const FormatException();
      return ContentModuleResponse.fromJson(data).toDomain();
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on Object {
      throw const NetworkException('Sunucudan geçersiz modül verisi alındı.');
    }
  }

  @override
  Future<ContentLesson> getLesson(String id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/education/content/lessons/$id',
      );
      final data = response.data;
      if (data == null) throw const FormatException();
      return ContentLessonResponse.fromJson(data).toDomain();
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on Object {
      throw const NetworkException('Sunucudan geçersiz ders verisi alındı.');
    }
  }

  @override
  Future<ContentQuiz?> getQuizForLesson(String lessonId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/education/content/lessons/$lessonId/quiz',
      );
      final data = response.data;
      if (data == null) throw const FormatException();
      return ContentQuizResponse.fromJson(data).toDomain();
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw mapNetworkException(error);
    } on Object {
      throw const NetworkException('Sunucudan geçersiz quiz verisi alındı.');
    }
  }

  @override
  Future<String> createModule(ModuleWriteInput input) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/education/modules',
        data: _moduleJson(input),
      );
      return response.data?['id'] as String;
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on Object {
      throw const NetworkException(
        'Modül oluşturulamadı. Lütfen tekrar deneyin.',
      );
    }
  }

  @override
  Future<void> updateModule(String id, ModuleWriteInput input) async {
    try {
      await _apiClient.dio.put<void>(
        '/api/education/modules/$id',
        data: _moduleJson(input),
      );
    } on DioException catch (error) {
      throw mapNetworkException(error);
    }
  }

  @override
  Future<void> deleteModule(String id) => _delete('/api/education/modules/$id');

  @override
  Future<String> createLesson(String moduleId, LessonWriteInput input) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/education/modules/$moduleId/lessons',
        data: _lessonJson(input),
      );
      return response.data?['id'] as String;
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on Object {
      throw const NetworkException(
        'Ders oluşturulamadı. Lütfen tekrar deneyin.',
      );
    }
  }

  @override
  Future<void> updateLesson(String id, LessonWriteInput input) async {
    try {
      await _apiClient.dio.put<void>(
        '/api/education/lessons/$id',
        data: _lessonJson(input),
      );
    } on DioException catch (error) {
      throw mapNetworkException(error);
    }
  }

  @override
  Future<void> deleteLesson(String id) => _delete('/api/education/lessons/$id');

  @override
  Future<String> createQuiz(String lessonId, QuizWriteInput input) =>
      _create('/api/education/lessons/$lessonId/quiz', _quizJson(input));

  @override
  Future<void> updateQuiz(String id, QuizWriteInput input) =>
      _update('/api/education/quizzes/$id', _quizJson(input));

  @override
  Future<void> deleteQuiz(String id) => _delete('/api/education/quizzes/$id');

  @override
  Future<String> createQuestion(String quizId, QuizQuestionWriteInput input) =>
      _create('/api/education/quizzes/$quizId/questions', _questionJson(input));

  @override
  Future<void> updateQuestion(String id, QuizQuestionWriteInput input) =>
      _update('/api/education/questions/$id', _questionJson(input));

  @override
  Future<void> deleteQuestion(String id) =>
      _delete('/api/education/questions/$id');

  @override
  Future<String> createOption(String questionId, QuizOptionWriteInput input) =>
      _create(
        '/api/education/questions/$questionId/options',
        _optionJson(input),
      );

  @override
  Future<void> updateOption(String id, QuizOptionWriteInput input) =>
      _update('/api/education/options/$id', _optionJson(input));

  Future<String> _create(String path, Map<String, Object> data) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        path,
        data: data,
      );
      return response.data?['id'] as String;
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on Object {
      throw const NetworkException(
        'İçerik kaydedilemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  Future<void> _update(String path, Map<String, Object> data) async {
    try {
      await _apiClient.dio.put<void>(path, data: data);
    } on DioException catch (error) {
      throw mapNetworkException(error);
    }
  }

  Future<void> _delete(String path) async {
    try {
      await _apiClient.dio.delete<void>(path);
    } on DioException catch (error) {
      throw mapNetworkException(error);
    }
  }

  static Map<String, Object> _moduleJson(ModuleWriteInput input) => {
    'title': input.title,
    'description': input.description,
    'order': input.order,
    'isPublished': input.isPublished,
  };

  static Map<String, Object> _lessonJson(LessonWriteInput input) => {
    'title': input.title,
    'description': input.description,
    'content': input.content,
    'estimatedDurationMinutes': input.estimatedDurationMinutes,
    'order': input.order,
    'isPublished': input.isPublished,
  };

  static Map<String, Object> _quizJson(QuizWriteInput input) => {
    'title': input.title,
    'isPublished': input.isPublished,
  };

  static Map<String, Object> _questionJson(QuizQuestionWriteInput input) => {
    'prompt': input.prompt,
    'order': input.order,
  };

  static Map<String, Object> _optionJson(QuizOptionWriteInput input) => {
    'text': input.text,
    'isCorrect': input.isCorrect,
    'order': input.order,
  };
}
