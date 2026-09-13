import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/core/network/network_exception.dart';
import 'package:asli_app/features/user_management/domain/models/user_activity_analytics.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userActivityRepositoryProvider = Provider<UserActivityRepository>(
  (ref) => DioUserActivityRepository(ref.watch(apiClientProvider)),
);

abstract interface class UserActivityRepository {
  Future<UserActivityAnalytics> getAnalytics(AnalyticsRange range);
}

final class DioUserActivityRepository implements UserActivityRepository {
  const DioUserActivityRepository(this._apiClient);
  final ApiClient _apiClient;

  @override
  Future<UserActivityAnalytics> getAnalytics(AnalyticsRange range) async {
    final base = '/api/admin/analytics/users/${range.userId}';
    final query = {
      'fromUtc': range.fromUtc.toUtc().toIso8601String(),
      'toUtc': range.toUtc.toUtc().toIso8601String(),
    };
    try {
      final responses = await Future.wait([
        _apiClient.dio.get<Map<String, dynamic>>(base, queryParameters: query),
        _apiClient.dio.get<List<dynamic>>(
          '$base/durations/screens',
          queryParameters: query,
        ),
        _apiClient.dio.get<List<dynamic>>(
          '$base/durations/modules',
          queryParameters: query,
        ),
        _apiClient.dio.get<List<dynamic>>(
          '$base/durations/lessons',
          queryParameters: query,
        ),
        _apiClient.dio.get<List<dynamic>>(
          '$base/quizzes',
          queryParameters: query,
        ),
        _apiClient.dio.get<List<dynamic>>(
          '$base/events',
          queryParameters: {...query, 'take': 100},
        ),
      ]);
      final summary = responses[0].data! as Map<String, dynamic>;
      List<dynamic> list(int index) => responses[index].data! as List<dynamic>;
      return UserActivityAnalytics(
        userId: summary['userId'] as String,
        displayName: summary['displayName'] as String,
        lastActiveAtUtc: summary['lastActiveAtUtc'] == null
            ? null
            : DateTime.parse(summary['lastActiveAtUtc'] as String),
        activeDurationSeconds: summary['activeDurationSeconds'] as int,
        sessionCount: summary['sessionCount'] as int,
        eventCount: summary['eventCount'] as int,
        screens: list(1).map(_duration).toList(),
        modules: list(2).map(_duration).toList(),
        lessons: list(3).map(_duration).toList(),
        quizzes: list(4).map((value) {
          final json = value as Map<String, dynamic>;
          return QuizActivity(
            title: json['quizTitle'] as String,
            attemptCount: json['attemptCount'] as int,
            durationSeconds: json['durationSeconds'] as int,
            averageScore: (json['averageScorePercentage'] as num?)?.toDouble(),
            bestScore: (json['bestScorePercentage'] as num?)?.toDouble(),
          );
        }).toList(),
        timeline: list(5).map((value) {
          final json = value as Map<String, dynamic>;
          return ActivityTimelineItem(
            eventType: json['eventType'] as String,
            occurredAtUtc: DateTime.parse(json['occurredAtUtc'] as String),
            screenName: json['screenName'] as String?,
            target: json['target'] as String?,
          );
        }).toList(),
      );
    } on DioException catch (error) {
      throw mapNetworkException(error);
    } on Object {
      throw const NetworkException('Kullanım analizi alınamadı.');
    }
  }

  static ActivityDuration _duration(Object? value) {
    final json = value as Map<String, dynamic>;
    return ActivityDuration(
      key: json['key'] as String,
      name: json['name'] as String?,
      durationSeconds: json['durationSeconds'] as int,
    );
  }
}
