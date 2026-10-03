import 'package:asli_app/features/quiz/domain/models/quiz_summary.dart';

List<QuizSummary> parseQuizSummaries(Object? value) {
  final summaries = (value as List<dynamic>? ?? const []).map((item) {
    final json = item as Map<String, dynamic>;
    return QuizSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      order: json['order'] as int,
      isPublished: json['isPublished'] as bool? ?? true,
    );
  }).toList();
  summaries.sort((a, b) {
    final order = a.order.compareTo(b.order);
    return order != 0 ? order : a.id.compareTo(b.id);
  });
  return List.unmodifiable(summaries);
}
