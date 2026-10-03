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
  test('yeni kullanıcı için başarı uydurulmaz', () {
    final overview = ProfileOverview(
      user: user,
      completedLessonCount: 0,
      quizResults: [],
    );
    expect(overview.averageSuccessPercentage, isNull);
    expect(overview.completedQuizCount, 0);
  });
  test('profil tamamlanan ders ve quiz sayılarını korur', () {
    final started = ProfileOverview(
      user: user,
      completedLessonCount: 1,
      quizResults: [],
    );
    expect(started.completedLessonCount, 1);
    final progressed = ProfileOverview(
      user: user,
      completedLessonCount: 5,
      quizResults: [testProfileQuizResult],
    );
    expect(progressed.completedLessonCount, 5);
    expect(progressed.completedQuizCount, 1);
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
