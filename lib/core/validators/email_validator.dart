class EmailValidator {
  EmailValidator._();

  static String? validateForRegister(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'El correo es obligatorio';
    }

    if (email.contains(' ')) {
      return 'El correo no puede contener espacios';
    }

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Ingresa un correo válido';
    }

    return null;
  }

  static bool isValidForRegister(String value) {
    return validateForRegister(value) == null;
  }

  static String? validateForLogin(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'El correo es obligatorio';
    }

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Ingresa un correo válido';
    }

    return null;
  }

  static bool isValidForLogin(String value) {
    return validateForLogin(value) == null;
  }
}