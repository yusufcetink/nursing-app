import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/profile/data/models/profile_api_models.dart';
import 'package:asli_app/features/profile/domain/models/profile_overview.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return DioProfileRepository(ref.watch(apiClientProvider));
});

abstract interface class ProfileRepository {
  Future<List<ProfileQuizResult>> getQuizHistory();

  Future<ProfileQuizResult> getQuizHistoryDetail(String attemptId);
}

final class DioProfileRepository implements ProfileRepository {
  const DioProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<ProfileQuizResult>> getQuizHistory() async {
    try {
      final response = await _apiClient.dio.get<List<dynamic>>(
        '/api/profile/quiz-history',
      );
      return (response.data ?? const [])
          .map(
            (item) =>
                QuizHistoryResponse.fromJson(item as Map<String, dynamic>)
                    .toDomain(),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Quiz geçmişi okunamadı.');
    } on TypeError {
      throw const NetworkException('Quiz geçmişi okunamadı.');
    }
  }

  @override
  Future<ProfileQuizResult> getQuizHistoryDetail(String attemptId) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/profile/quiz-history/$attemptId',
      );
      final data = response.data;
      if (data == null) throw const FormatException();
      return QuizHistoryResponse.fromJson(data).toDomain();
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on FormatException {
      throw const NetworkException('Quiz sonucu okunamadı.');
    } on TypeError {
      throw const NetworkException('Quiz sonucu okunamadı.');
    }
  }
}
