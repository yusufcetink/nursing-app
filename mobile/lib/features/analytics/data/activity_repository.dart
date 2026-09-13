import 'package:asli_app/core/network/api_client.dart';
import 'package:asli_app/features/analytics/domain/activity_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => DioActivityRepository(ref.watch(apiClientProvider)),
);

abstract interface class ActivityRepository {
  Future<void> sendBatch(List<ActivityEvent> events);
}

final class DioActivityRepository implements ActivityRepository {
  const DioActivityRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> sendBatch(List<ActivityEvent> events) async {
    await _apiClient.dio.post<void>(
      '/api/activity/events/batch',
      data: {'events': events.map((event) => event.toJson()).toList()},
    );
  }
}
