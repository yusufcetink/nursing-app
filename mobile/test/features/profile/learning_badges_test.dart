import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/profile/domain/models/profile_overview.dart';
import 'package:asli_app/features/profile/domain/models/profile_user.dart';
import 'package:asli_app/features/auth/domain/models/user_role.dart';

import '../../helpers/fake_learning_repositories.dart';

void main() {
  const user = ProfileUser(
    firstName: 'Ayşe',
    lastName: 'Yılmaz',
    email: '',
    role: UserRole.student,
  );
  test('yeni kullanıcı için başarı uydurulmaz ve rozet verilmez', () {
    final overview = ProfileOverview(
      user: user,
      completedLessonCount: 0,
      quizResults: [],
    );
    expect(overview.averageSuccessPercentage, isNull);
    expect(overview.earnedBadges, isEmpty);
  });
  test('ders ve quiz rozetleri yalnızca tamamlanınca açılır', () {
    final started = ProfileOverview(
      user: user,
      completedLessonCount: 1,
      quizResults: [],
    );
    expect(started.earnedBadges, {LearningBadge.firstLesson});
    final progressed = ProfileOverview(
      user: user,
      completedLessonCount: 5,
      quizResults: [testProfileQuizResult],
    );
    expect(progressed.earnedBadges, LearningBadge.values.toSet());
    expect(progressed.averageSuccessPercentage, 100);
  });
  test('boş isim profil avatarında hataya yol açmaz', () {
    const anonymous = ProfileUser(
      firstName: '',
      lastName: ' ',
      email: '',
      role: UserRole.student,
    );
    expect(anonymous.initials, 'A');
    expect(user.initials, 'AY');
  });
}
