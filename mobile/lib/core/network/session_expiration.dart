import 'package:flutter_riverpod/flutter_riverpod.dart';

// Network code reports expiration without depending on feature controllers.
final sessionExpirationProvider = NotifierProvider<SessionExpiration, int>(
  SessionExpiration.new,
);

final class SessionExpiration extends Notifier<int> {
  @override
  int build() => 0;
  void notify() => state++;
}
