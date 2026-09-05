import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/education/data/models/education_api_models.dart';
import 'package:asli_app/features/education/domain/models/education_module.dart';
import 'package:asli_app/features/education/domain/models/lesson.dart';

final educationRepositoryProvider = Provider<EducationRepository>((ref) {
  return DioEducationRepository(ref.watch(apiClientProvider));
});

abstract interface class EducationRepository {
  Future<List<EducationModule>> getModules();

  Future<EducationModule> getModule(String id);

  Future<Lesson> getLesson(String id);
}

final class DioEducationRepository implements EducationRepository {
  const DioEducationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<EducationModule>> getModules() async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>(
        '/api/education/modules',
      );
      return (response.data ?? const [])
          .map(
            (item) => EducationModuleSummaryResponse.fromJson(
              item as Map<String, dynamic>,
            ).toDomain(),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Sunucudan geçersiz modül verisi alındı.');
    } on TypeError {
      throw const NetworkException('Sunucudan geçersiz modül verisi alındı.');
    }
  }

  @override
  Future<EducationModule> getModule(String id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/education/modules/$id',
      );
      final data = response.data;
      if (data == null) throw const FormatException();
      return EducationModuleResponse.fromJson(data).toDomain();
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Sunucudan geçersiz modül verisi alındı.');
    } on TypeError {
      throw const NetworkException('Sunucudan geçersiz modül verisi alındı.');
    }
  }

  @override
  Future<Lesson> getLesson(String id) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/education/lessons/$id',
      );
      final data = response.data;
      if (data == null) throw const FormatException();
      return LessonResponse.fromJson(data).toDomain();
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Sunucudan geçersiz ders verisi alındı.');
    } on TypeError {
      throw const NetworkException('Sunucudan geçersiz ders verisi alındı.');
    }
  }
}
