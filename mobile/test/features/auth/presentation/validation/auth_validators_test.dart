import 'package:flutter_test/flutter_test.dart';
import 'package:asli_app/features/auth/presentation/validation/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('zorunlu alanları ve email biçimini doğrular', () {
      expect(AuthValidators.requiredField('  ', 'Ad'), 'Ad alanı zorunludur.');
      expect(AuthValidators.email('gecersiz-email'), isNotNull);
      expect(AuthValidators.email('student@example.com'), isNull);
    });

    test('şifre uzunluğunu ve tekrarını doğrular', () {
      expect(AuthValidators.password('short'), isNotNull);
      expect(AuthValidators.password('password123'), isNull);
      expect(
        AuthValidators.passwordConfirmation('different', 'password123'),
        'Şifreler eşleşmiyor.',
      );
      expect(
        AuthValidators.passwordConfirmation('password123', 'password123'),
        isNull,
      );
    });

    test('doğrulama kodunu 6 rakamla sınırlar', () {
      expect(AuthValidators.verificationCode('123456'), isNull);
      expect(AuthValidators.verificationCode('12345'), isNotNull);
      expect(AuthValidators.verificationCode('12345a'), isNotNull);
    });
  });
}
