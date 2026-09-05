import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/progress/data/models/progress_api_models.dart';
import 'package:asli_app/features/progress/domain/models/progress_state.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return DioProgressRepository(ref.watch(apiClientProvider));
});

abstract interface class ProgressRepository {
  Future<ProgressState> getProgress();

  Future<CompletedLesson> completeLesson(String lessonId);
}

final class DioProgressRepository implements ProgressRepository {
  const DioProgressRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<ProgressState> getProgress() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/profile/progress',
      );
      final data = response.data;
      if (data == null) throw const FormatException();
      return ProgressResponse.fromJson(data).toDomain();
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('İlerleme bilgisi okunamadı.');
    } on TypeError {
      throw const NetworkException('İlerleme bilgisi okunamadı.');
    }
  }

  @override
  Future<CompletedLesson> completeLesson(String lessonId) async {
    try {
      final response = await _apiClient.dio.put<Map<String, dynamic>>(
        '/api/education/lessons/$lessonId/progress',
      );
      final data = response.data;
      if (data == null) throw const FormatException();
      return CompletedLessonResponse.fromJson(data).toDomain();
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Ders ilerlemesi kaydedilemedi.');
    } on TypeError {
      throw const NetworkException('Ders ilerlemesi kaydedilemedi.');
    }
  }
}
