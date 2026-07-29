import 'package:flutter_test/flutter_test.dart';
import 'package:magic_dates/features/couple/models/pair_invitation.dart';
import 'package:magic_dates/features/couple/providers/pair_invitation_controller.dart';
import 'package:magic_dates/features/couple/services/pair_invitation_service.dart';

void main() {
  test('carga una invitación activa y calcula el tiempo restante', () async {
    final service = _FakePairInvitationGateway(
      invitation: PairInvitation(
        code: 'ABC123',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
    final controller = PairInvitationController(service);

    await controller.loadInvitation();

    expect(controller.status, PairInvitationStatus.ready);
    expect(controller.invitation?.code, 'ABC123');
    expect(controller.canShare, isTrue);
    expect(controller.remaining.inMinutes, anyOf(14, 15));

    controller.dispose();
  });

  test('expone el mensaje seguro cuando falla la generación', () async {
    final service = _FakePairInvitationGateway(
      error: const PairInvitationException('No se pudo generar el código.'),
    );
    final controller = PairInvitationController(service);

    await controller.loadInvitation();

    expect(controller.status, PairInvitationStatus.error);
    expect(controller.errorMessage, 'No se pudo generar el código.');

    controller.dispose();
  });

  test('marca la vinculación como completada', () async {
    final service = _FakePairInvitationGateway(
      invitation: PairInvitation(
        code: 'KTR004',
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
    final controller = PairInvitationController(service);

    await controller.loadInvitation();
    final linked = await controller.acceptInvitation('MNP980');

    expect(linked, isTrue);
    expect(controller.status, PairInvitationStatus.linked);
    expect(service.acceptedCode, 'MNP980');

    controller.dispose();
  });
}

class _FakePairInvitationGateway implements PairInvitationGateway {
  _FakePairInvitationGateway({
    this.invitation,
    this.error,
  });

  final PairInvitation? invitation;
  final PairInvitationException? error;
  String? acceptedCode;

  @override
  Future<PairInvitation> createOrRecoverInvitation() async {
    if (error != null) throw error!;
    return invitation!;
  }

  @override
  Future<void> acceptInvitation(String code) async {
    acceptedCode = code;
  }
}
