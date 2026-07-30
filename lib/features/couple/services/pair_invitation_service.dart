import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/pair_invitation.dart';

class PairInvitationException implements Exception {
  const PairInvitationException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum PairInvitationLinkStatus {
  available,
  used,
  cancelled,
  expired,
  ownCode,
  invalid,
  unavailable,
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
  static final Map<String, PairInvitation> _invitationCache = {};

  Future<PairInvitationLinkStatus> getInvitationStatus(String code) async {
    try {
      final result =
          await _functions.httpsCallable('getPairInvitationStatus').call({
        'code': code.trim().toUpperCase(),
      });
      final data = Map<String, dynamic>.from(result.data as Map);

      return switch (data['status']) {
        'available' => PairInvitationLinkStatus.available,
        'used' => PairInvitationLinkStatus.used,
        'cancelled' => PairInvitationLinkStatus.cancelled,
        'expired' => PairInvitationLinkStatus.expired,
        'own-code' => PairInvitationLinkStatus.ownCode,
        'invalid' => PairInvitationLinkStatus.invalid,
        _ => PairInvitationLinkStatus.unavailable,
      };
    } on FirebaseFunctionsException catch (error) {
      throw PairInvitationException(_messageFor(error));
    } catch (_) {
      throw const PairInvitationException(
        'No se pudo comprobar la invitación. Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<PairInvitation> createOrRecoverInvitation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cachedInvitation = uid == null ? null : _invitationCache[uid];

    if (cachedInvitation != null &&
        !cachedInvitation.isExpiredAt(DateTime.now())) {
      return cachedInvitation;
    }

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

      final invitation = PairInvitation(
        code: code,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMillis.toInt()),
      );
      if (uid != null) _invitationCache[uid] = invitation;
      return invitation;
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) _invitationCache.remove(uid);
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
