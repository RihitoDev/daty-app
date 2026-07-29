import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pair_invitation.dart';
import '../services/pair_invitation_service.dart';

enum PairInvitationStatus {
  loading,
  ready,
  expired,
  validating,
  linked,
  error,
}

class PairInvitationController extends ChangeNotifier {
  PairInvitationController(this._service);

  final PairInvitationGateway _service;

  PairInvitation? _invitation;
  PairInvitationStatus _status = PairInvitationStatus.loading;
  Duration _remaining = Duration.zero;
  String? _errorMessage;
  Timer? _timer;

  PairInvitation? get invitation => _invitation;
  PairInvitationStatus get status => _status;
  Duration get remaining => _remaining;
  String? get errorMessage => _errorMessage;

  bool get canShare =>
      _status == PairInvitationStatus.ready &&
      _invitation != null &&
      _remaining > Duration.zero;

  Future<void> loadInvitation() async {
    _timer?.cancel();
    _status = PairInvitationStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _invitation = await _service.createOrRecoverInvitation();
      _syncRemaining();
      if (_remaining == Duration.zero) {
        _status = PairInvitationStatus.expired;
      } else {
        _status = PairInvitationStatus.ready;
        _startTimer();
      }
    } on PairInvitationException catch (error) {
      _status = PairInvitationStatus.error;
      _errorMessage = error.message;
    } catch (_) {
      _status = PairInvitationStatus.error;
      _errorMessage = 'No se pudo generar el código. Inténtalo nuevamente.';
    }

    notifyListeners();
  }

  Future<bool> acceptInvitation(String code) async {
    if (_status == PairInvitationStatus.validating) return false;

    _status = PairInvitationStatus.validating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.acceptInvitation(code);
      _status = PairInvitationStatus.linked;
      _timer?.cancel();
      notifyListeners();
      return true;
    } on PairInvitationException catch (error) {
      _status = _invitation?.isExpiredAt(DateTime.now()) == true
          ? PairInvitationStatus.expired
          : PairInvitationStatus.ready;
      _errorMessage = error.message;
    } catch (_) {
      _status = PairInvitationStatus.ready;
      _errorMessage = 'No se pudo validar la invitación.';
    }

    notifyListeners();
    return false;
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncRemaining();
      if (_remaining == Duration.zero) {
        _timer?.cancel();
        _status = PairInvitationStatus.expired;
      }
      notifyListeners();
    });
  }

  void _syncRemaining() {
    _remaining = _invitation?.remainingAt(DateTime.now()) ?? Duration.zero;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
