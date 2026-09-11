import 'package:asli_app/features/progress/domain/models/progress_state.dart';

/// Calendar-based activity; multiple completions on one day count as one day.
final class LearningActivity {
  LearningActivity({required this.todayCount, required List<bool> weekDays})
    : weekDays = List.unmodifiable(weekDays);

  factory LearningActivity.fromProgress(ProgressState progress, DateTime now) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final dates = progress.completedLessons
        .map((lesson) => lesson.completedAtUtc.toLocal())
        .where((date) => !date.isAfter(localNow));
    final uniqueDays = dates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
    return LearningActivity(
      todayCount: dates
          .where(
            (date) =>
                date.year == today.year &&
                date.month == today.month &&
                date.day == today.day,
          )
          .length,
      weekDays: List.generate(
        7,
        (i) => uniqueDays.contains(
          DateTime(monday.year, monday.month, monday.day + i),
        ),
      ),
    );
  }

  final int todayCount;
  final List<bool> weekDays;
  int get activeDays => weekDays.where((day) => day).length;
}
