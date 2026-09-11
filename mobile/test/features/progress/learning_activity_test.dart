import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/progress/domain/models/learning_activity.dart';
import 'package:asli_app/features/progress/domain/models/progress_state.dart';

void main() {
  CompletedLesson completed(String id, DateTime localDate) => CompletedLesson(
    lessonId: id,
    educationModuleId: 'module',
    completedAtUtc: localDate.toUtc(),
  );

  test('aynı gündeki dersler ayrı sayılır, haftalık gün tek sayılır', () {
    final activity = LearningActivity.fromProgress(
      ProgressState(
        completedLessons: [
          completed('a', DateTime(2026, 9, 11, 8)),
          completed('b', DateTime(2026, 9, 11, 9)),
          completed('c', DateTime(2026, 9, 7, 10)),
        ],
      ),
      DateTime(2026, 9, 11, 12),
    );
    expect(activity.todayCount, 2);
    expect(activity.activeDays, 2);
    expect(activity.weekDays, [true, false, false, false, true, false, false]);
  });

  test('önceki hafta ve gelecekteki kayıtlar bugünkü ritmi değiştirmez', () {
    final activity = LearningActivity.fromProgress(
      ProgressState(
        completedLessons: [
          completed('old', DateTime(2026, 9, 6, 23)),
          completed('future', DateTime(2026, 9, 12)),
        ],
      ),
      DateTime(2026, 9, 11, 12),
    );
    expect(activity.todayCount, 0);
    expect(activity.activeDays, 0);
  });

  test('yerel gece yarısı ve ay sınırında haftayı doğru hesaplar', () {
    final activity = LearningActivity.fromProgress(
      ProgressState(
        completedLessons: [
          completed('monday', DateTime(2026, 8, 31, 23, 50)),
          completed('tuesday', DateTime(2026, 9, 1, 0, 5)),
        ],
      ),
      DateTime(2026, 9, 1, 0, 10),
    );
    expect(activity.todayCount, 1);
    expect(activity.weekDays, [true, true, false, false, false, false, false]);
  });
}
