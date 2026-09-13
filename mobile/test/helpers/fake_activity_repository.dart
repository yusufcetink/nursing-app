import 'package:asli_app/features/analytics/data/activity_repository.dart';
import 'package:asli_app/features/analytics/domain/activity_event.dart';

export 'package:asli_app/features/analytics/data/activity_repository.dart';

class FakeActivityRepository implements ActivityRepository {
  final List<ActivityEvent> events = [];

  @override
  Future<void> sendBatch(List<ActivityEvent> events) async {
    this.events.addAll(events);
  }
}
