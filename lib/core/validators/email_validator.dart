class EmailValidator {
  EmailValidator._();

  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.(com|org|net|edu)$',
  );

  static bool isValid(String email) {
    return _emailRegex.hasMatch(email.trim());
  }

  static String? validate(String email) {
    final value = email.trim();

    if (value.isEmpty) {
      return 'El correo es obligatorio';
    }

    if (!_emailRegex.hasMatch(value)) {
      return 'Ingresa un correo electrónico válido';
    }

    return null;
  }
}
