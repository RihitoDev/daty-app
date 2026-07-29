String? validateEmailAddress(String? value) {
  final email = value?.trim() ?? '';

  if (email.isEmpty) {
    return 'El correo es obligatorio';
  }

  if (email.contains(RegExp(r'\s'))) {
    return 'El correo no puede contener espacios';
  }

  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailPattern.hasMatch(email)) {
    return 'Ingresa un correo electrónico válido';
  }

  return null;
}
