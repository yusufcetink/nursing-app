final class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.prompt,
    required List<QuizOption> options,
  }) : options = List.unmodifiable(options);

  final String id;
  final String prompt;
  final List<QuizOption> options;
}

final class QuizOption {
  const QuizOption({required this.id, required this.text});

  final String id;
  final String text;
}
