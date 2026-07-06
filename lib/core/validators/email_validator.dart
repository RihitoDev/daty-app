class EmailValidator {
  EmailValidator._();

  static final RegExp _emailRegex = RegExp(
  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.(com|org|net|edu)$',
);

  /// Devuelve true si el correo tiene un formato válido.
  static bool isValid(String email) {
    return _emailRegex.hasMatch(email.trim());
  }

  /// Devuelve un mensaje de error o null si el correo es válido.
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