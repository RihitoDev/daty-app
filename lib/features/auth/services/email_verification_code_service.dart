import 'package:cloud_functions/cloud_functions.dart';

class VerificationCodeSendResult {
  const VerificationCodeSendResult({
    required this.alreadyVerified,
    required this.resendAvailableAt,
  });

  final bool alreadyVerified;
  final DateTime resendAvailableAt;
}

class VerificationCodeResult {
  const VerificationCodeResult({
    required this.verified,
    required this.alreadyVerified,
  });

  final bool verified;
  final bool alreadyVerified;
}

class EmailVerificationCodeException implements Exception {
  const EmailVerificationCodeException({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final dynamic details;
}

class EmailVerificationCodeService {
  EmailVerificationCodeService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<VerificationCodeSendResult> sendCode() async {
    try {
      final callable = _functions.httpsCallable('sendEmailVerificationCode');
      final response = await callable.call<Map<String, dynamic>>();
      final data = response.data;

      return VerificationCodeSendResult(
        alreadyVerified: data['alreadyVerified'] == true,
        resendAvailableAt: DateTime.fromMillisecondsSinceEpoch(
          (data['resendAvailableAtMillis'] as num?)?.toInt() ?? 0,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      throw EmailVerificationCodeException(
        code: error.code,
        message: error.message ?? 'No se pudo enviar el código.',
        details: error.details,
      );
    }
  }

  Future<VerificationCodeResult> verifyCode(String code) async {
    try {
      final callable = _functions.httpsCallable('verifyEmailVerificationCode');
      final response = await callable.call<Map<String, dynamic>>({
        'code': code,
      });
      final data = response.data;

      return VerificationCodeResult(
        verified: data['verified'] == true,
        alreadyVerified: data['alreadyVerified'] == true,
      );
    } on FirebaseFunctionsException catch (error) {
      throw EmailVerificationCodeException(
        code: error.code,
        message: error.message ?? 'No se pudo verificar el código.',
        details: error.details,
      );
    }
  }
}
