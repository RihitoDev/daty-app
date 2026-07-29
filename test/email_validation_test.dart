import 'package:flutter_test/flutter_test.dart';
import 'package:magic_dates/features/auth/utils/email_validation.dart';

void main() {
  group('validateEmailAddress', () {
    test('acepta dominios legítimos sin restringir el TLD', () {
      expect(validateEmailAddress('persona@ejemplo.dev'), isNull);
      expect(validateEmailAddress('nombre+tag@subdominio.co.uk'), isNull);
    });

    test('rechaza correo vacío, espacios y formato incompleto', () {
      expect(validateEmailAddress(''), isNotNull);
      expect(validateEmailAddress('persona @ejemplo.com'), isNotNull);
      expect(validateEmailAddress('persona@ejemplo'), isNotNull);
    });
  });
}
