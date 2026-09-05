abstract final class AuthValidators {
  static const minimumPasswordLength = 8;

  static String? requiredField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName alanı zorunludur.';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = requiredField(value, 'Email');
    if (requiredError != null) {
      return requiredError;
    }

    final normalizedEmail = value!.trim();
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(normalizedEmail)) {
      return 'Geçerli bir email adresi girin.';
    }
    return null;
  }

  static String? password(String? value) {
    final requiredError = requiredField(value, 'Şifre');
    if (requiredError != null) {
      return requiredError;
    }
    if (value!.length < minimumPasswordLength) {
      return 'Şifre en az $minimumPasswordLength karakter olmalıdır.';
    }
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    final requiredError = requiredField(value, 'Şifre tekrarı');
    if (requiredError != null) {
      return requiredError;
    }
    if (value != password) {
      return 'Şifreler eşleşmiyor.';
    }
    return null;
  }

  static String? verificationCode(String? value) {
    final requiredError = requiredField(value, 'Doğrulama kodu');
    if (requiredError != null) {
      return requiredError;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value!.trim())) {
      return 'Doğrulama kodu 6 rakamdan oluşmalıdır.';
    }
    return null;
  }
}
