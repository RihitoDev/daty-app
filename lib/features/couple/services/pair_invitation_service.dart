import 'package:cloud_functions/cloud_functions.dart';

import '../models/pair_invitation.dart';

class PairInvitationException implements Exception {
  const PairInvitationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class PairInvitationGateway {
  Future<PairInvitation> createOrRecoverInvitation();
  Future<void> acceptInvitation(String code);
}

class PairInvitationService implements PairInvitationGateway {
  PairInvitationService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  @override
  Future<PairInvitation> createOrRecoverInvitation() async {
    try {
      final result =
          await _functions.httpsCallable('createPairInvitation').call();
      final data = Map<String, dynamic>.from(result.data as Map);
      final code = data['code'] as String?;
      final expiresAtMillis = data['expiresAtMillis'] as num?;

      if (code == null || expiresAtMillis == null) {
        throw const PairInvitationException(
          'Firebase devolvió una invitación incompleta.',
        );
      }

      return PairInvitation(
        code: code,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMillis.toInt()),
      );
    } on FirebaseFunctionsException catch (error) {
      throw PairInvitationException(_messageFor(error));
    }
  }

  @override
  Future<void> acceptInvitation(String code) async {
    try {
      await _functions.httpsCallable('acceptPairInvitation').call({
        'code': code.trim().toUpperCase(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw PairInvitationException(_messageFor(error));
    }
  }

  String _messageFor(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;

    switch (error.code) {
      case 'not-found':
        return 'El código no existe.';
      case 'deadline-exceeded':
        return 'La invitación ha vencido.';
      case 'already-exists':
        return 'Esta invitación ya fue utilizada.';
      case 'unauthenticated':
        return 'Debes iniciar sesión nuevamente.';
      case 'unavailable':
        return 'No se pudo conectar. Revisa tu conexión.';
      default:
        return 'Ocurrió un problema. Inténtalo nuevamente.';
    }
  }
}
