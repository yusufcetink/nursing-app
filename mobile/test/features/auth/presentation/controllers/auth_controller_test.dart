import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/auth/data/auth_repository.dart';
import 'package:asli_app/features/auth/presentation/controllers/auth_controller.dart';

import '../../../../helpers/fake_auth_repository.dart';

void main() {
  test('login ve logout auth state geçişlerini yönetir', () async {
    final repository = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final loggedIn = await container
        .read(authControllerProvider.notifier)
        .login(email: 'student@example.com', password: 'SecurePass1!');

    expect(loggedIn, isTrue);
    expect(
      container.read(authControllerProvider).value,
      FakeAuthRepository.user,
    );
    expect(repository.loginCallCount, 1);

    final loggedOut = await container
        .read(authControllerProvider.notifier)
        .logout();

    expect(loggedOut, isTrue);
    expect(container.read(authControllerProvider).value, isNull);
    expect(repository.logoutCallCount, 1);
  });

  test('register hatasını UI için state üzerinde korur', () async {
    const error = AuthException('Kayıt tamamlanamadı.');
    final repository = FakeAuthRepository(error: error);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final registered = await container
        .read(authControllerProvider.notifier)
        .register(
          firstName: 'Ayşe',
          lastName: 'Yılmaz',
          email: 'ayse@example.com',
          password: 'SecurePass1!',
        );

    expect(registered, isFalse);
    expect(container.read(authControllerProvider).error, error);
    expect(repository.registerCallCount, 1);
  });
}
