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

  Future<String> createModule(ModuleWriteInput input);

  Future<void> updateModule(String id, ModuleWriteInput input);

  Future<String> createLesson(String moduleId, LessonWriteInput input);

  Future<void> updateLesson(String id, LessonWriteInput input);
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
}
