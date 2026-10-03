final class QuizSummary {
  const QuizSummary({
    required this.id,
    required this.title,
    required this.order,
    this.isPublished = true,
  });
  final String id;
  final String title;
  final int order;
  final bool isPublished;
}
