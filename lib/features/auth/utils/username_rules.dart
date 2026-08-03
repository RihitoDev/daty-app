class UsernameRules {
  static const int minLength = 2;
  static const int maxLength = 20;
  static const int maxSpaces = 3;

  static String clean(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static bool isValid(String value) {
    final username = clean(value);
    return username.length >= minLength &&
        username.length <= maxLength &&
        RegExp(r'\s').allMatches(username).length <= maxSpaces;
  }

  static String? validationMessage(String value) {
    final username = clean(value);
    if (username.isEmpty) return 'Escribe un nombre de usuario';
    if (username.length < minLength) return 'Usa al menos 2 caracteres';
    if (username.length > maxLength) return 'Usa como máximo 20 caracteres';
    if (RegExp(r'\s').allMatches(username).length > maxSpaces) {
      return 'Puedes usar como máximo tres espacios';
    }
    return null;
  }
}
