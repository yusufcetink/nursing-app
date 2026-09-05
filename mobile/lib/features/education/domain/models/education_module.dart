import 'package:asli_app/features/education/domain/models/lesson.dart';

final class EducationModule {
  const EducationModule({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.lessonCount,
    required this.lessons,
  });

  final String id;
  final String title;
  final String description;
  final int order;
  final int lessonCount;
  final List<Lesson> lessons;
}
