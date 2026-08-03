import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../../auth/providers/auth_provider.dart';

class SettingsProvider with ChangeNotifier {
  final AuthProvider _authProvider;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  SettingsProvider(this._authProvider);

  /// Reiniciar solo el mapa solitario (New Game+): Conserva el Álbum de Recuerdos
  /// y aplica 50% de XP a las aventuras que ya se completaron previamente.
  Future<String?> resetSoloMapOnly() async {
    _isProcessing = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;

      // Leemos los IDs de las aventuras previamente completadas para marcarlas como repetidas
      final memoriesSnap = await FirebaseFirestore.instance
          .collection('solo_memories')
          .where('userId', isEqualTo: myUid)
          .get();

      final List<int> prevCompletedIds = [];
      for (final doc in memoriesSnap.docs) {
        final rawId = doc.data()['adventureId'];
        if (rawId is int) {
          prevCompletedIds.add(rawId);
        } else if (rawId != null) {
          final parsed = int.tryParse(rawId.toString());
          if (parsed != null) prevCompletedIds.add(parsed);
        }
      }

      // Reiniciamos el mapa marcando las aventuras previamente completadas
      await FirebaseFirestore.instance.collection('solo_progress').doc(myUid).set(
        {
          'activeAdventureNumber': FieldValue.delete(),
          'adventurePath': [],
          'previouslyCompletedIds': prevCompletedIds,
          'isReplayed': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _isProcessing = false;
      notifyListeners();
      return null;
    } catch (e, stack) {
      debugPrint('Error al reiniciar mapa solitario: $e\n$stack');
      _isProcessing = false;
      notifyListeners();
      return 'Error al reiniciar el mapa: $e';
    }
  }

  /// Reinicio Completo de Fábrica: Borra mapa, Álbum Solitario y resetea XP a 0.
  Future<String?> resetSoloFactory() async {
    _isProcessing = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;

      // 1. Borramos el documento del mapa
      try {
        await FirebaseFirestore.instance.collection('solo_progress').doc(myUid).delete();
      } catch (e) {
        debugPrint('Error borrando solo_progress: $e');
      }

      // 2. Borramos todos los recuerdos del Álbum Solitario (solo_memories y recuerdos personales/solitarios)
      try {
        final List<DocumentReference> refsToDelete = [];

        final allSoloSnap = await FirebaseFirestore.instance.collection('solo_memories').get();
        for (final doc in allSoloSnap.docs) {
          final data = doc.data();
          final uId = data['userId'] ?? data['user1Id'] ?? data['uid'] ?? data['ownerId'];
          if (uId == myUid || doc.id.startsWith(myUid) || doc.id.contains(myUid)) {
            refsToDelete.add(doc.reference);
          }
        }

        final memoriesSnap = await FirebaseFirestore.instance.collection('memories').get();
        for (final doc in memoriesSnap.docs) {
          final data = doc.data();
          final uId = data['userId'] ?? data['user1Id'] ?? data['ownerId'];
          final isPersonal = data['isPersonal'] == true;
          final mode = data['mode'];
          if (uId == myUid && (isPersonal || mode == 'solo')) {
            refsToDelete.add(doc.reference);
          }
        }

        for (int i = 0; i < refsToDelete.length; i += 400) {
          final chunk = refsToDelete.sublist(
            i,
            i + 400 > refsToDelete.length ? refsToDelete.length : i + 400,
          );
          final batch = FirebaseFirestore.instance.batch();
          for (final ref in chunk) {
            batch.delete(ref);
          }
          await batch.commit();
        }
      } catch (e) {
        debugPrint('Error borrando recuerdos en resetSoloFactory: $e');
      }

      // 3. Restablecemos XP y contador en el perfil del usuario
      try {
        await FirebaseFirestore.instance.collection('users').doc(myUid).set({
          'exp': 0,
          'soloDatesCompleted': 0,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error reseteando perfil en users: $e');
      }

      _isProcessing = false;
      notifyListeners();
      return null;
    } catch (e, stack) {
      debugPrint('Error al borrar progreso completo: $e\n$stack');
      _isProcessing = false;
      notifyListeners();
      return 'Error al realizar el borrado de fábrica: $e';
    }
  }

  /// Desvincular pareja con ventana de 72 horas para recuperar vínculo y 7 días para resguardo
  Future<String?> unlinkPartnerWithGracePeriod() async {
    _isProcessing = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;
      final myDocRef = FirebaseFirestore.instance.collection('users').doc(myUid);

      final result = await FirebaseFirestore.instance.runTransaction((transaction) async {
        final myDoc = await transaction.get(myDocRef);
        final partnerId = myDoc.data()?['partnerId'] as String?;

        if (partnerId == null) return 'unlink_no_partner';

        final partnerRef = FirebaseFirestore.instance.collection('users').doc(partnerId);
        final partnerDoc = await transaction.get(partnerRef);

        String coupleDocId = myUid.compareTo(partnerId) < 0
            ? '${myUid}_$partnerId'
            : '${partnerId}_$myUid';

        final coupleRef = FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId);

        final now = DateTime.now();
        final recoveryEnd = now.add(const Duration(hours: 72));
        final preservationEnd = now.add(const Duration(days: 7));

        // Desvinculamos partnerId en ambos usuarios para que puedan rehacer su vida si lo desean
        transaction.update(myDocRef, {'partnerId': null});
        if (partnerDoc.exists && partnerDoc.data()?['partnerId'] == myUid) {
          transaction.update(partnerRef, {'partnerId': null});
        }

        // Marcamos la sala compartida en estado de separación con ventanas temporales
        transaction.set(
          coupleRef,
          {
            'unlinkingState': 'paused',
            'unlinkedBy': myUid,
            'unlinkedAt': Timestamp.fromDate(now),
            'recoveryWindowEnd': Timestamp.fromDate(recoveryEnd),
            'preservationWindowEnd': Timestamp.fromDate(preservationEnd),
            'user1Id': myUid.compareTo(partnerId) < 0 ? myUid : partnerId,
            'user2Id': myUid.compareTo(partnerId) < 0 ? partnerId : myUid,
            'reconciliationStatus': FieldValue.delete(),
            'reconciliationRequestedBy': FieldValue.delete(),
            'reconciliationSignedUser1': FieldValue.delete(),
            'reconciliationSignedUser2': FieldValue.delete(),
            'reconciliationRequestedAt': FieldValue.delete(),
          },
          SetOptions(merge: true),
        );

        return null;
      });

      if (result == 'unlink_no_partner') {
        _isProcessing = false;
        notifyListeners();
        return null;
      }

      _isProcessing = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Error al desvincular pareja: $e');
      _isProcessing = false;
      notifyListeners();
      return 'Error al desvincular. Inténtalo de nuevo.';
    }
  }

  /// Recuperar vínculo de pareja dentro de las 72 horas
  Future<String?> recoverPartnerLink(String coupleDocId) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;

      String? targetPartnerId;

      final result = await FirebaseFirestore.instance.runTransaction((transaction) async {
        final coupleRef = FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId);
        final coupleDoc = await transaction.get(coupleRef);

        if (!coupleDoc.exists) return 'no_couple_doc';

        final data = coupleDoc.data()!;
        final recoveryEnd = (data['recoveryWindowEnd'] as Timestamp?)?.toDate();

        if (recoveryEnd == null || DateTime.now().isAfter(recoveryEnd)) {
          return 'recovery_expired';
        }

        final String? rawUser1 = data['user1Id'] ?? data['user1'];
        final String? rawUser2 = data['user2Id'] ?? data['user2'];
        String user1Id = rawUser1 ?? '';
        String user2Id = rawUser2 ?? '';

        if (user1Id.isEmpty || user2Id.isEmpty) {
          final parts = coupleDocId.split('_');
          if (parts.length == 2) {
            user1Id = parts[0];
            user2Id = parts[1];
          }
        }

        final partnerId = myUid == user1Id ? user2Id : user1Id;
        targetPartnerId = partnerId;

        final myDocRef = FirebaseFirestore.instance.collection('users').doc(myUid);
        final partnerDocRef = FirebaseFirestore.instance.collection('users').doc(partnerId);

        final myDoc = await transaction.get(myDocRef);
        final partnerDoc = await transaction.get(partnerDocRef);

        // Si alguno ya se vinculó con UNA TERCERA PERSONA, se cancela la recuperación
        final myCurrentPartner = myDoc.data()?['partnerId'];
        final partnerCurrentPartner = partnerDoc.data()?['partnerId'];
        if ((myCurrentPartner != null && myCurrentPartner != partnerId) ||
            (partnerCurrentPartner != null && partnerCurrentPartner != myUid)) {
          return 'already_relinked_with_someone_else';
        }

        // Restauramos mi vínculo y reactivamos la pareja con firmas en true
        transaction.update(myDocRef, {'partnerId': partnerId});
        transaction.update(coupleRef, {
          'contractSignedUser1': true,
          'contractSignedUser2': true,
          'unlinkingState': FieldValue.delete(),
          'unlinkedBy': FieldValue.delete(),
          'unlinkedAt': FieldValue.delete(),
          'recoveryWindowEnd': FieldValue.delete(),
          'preservationWindowEnd': FieldValue.delete(),
          'reconciliationStatus': FieldValue.delete(),
          'reconciliationRequestedBy': FieldValue.delete(),
          'reconciliationSignedUser1': FieldValue.delete(),
          'reconciliationSignedUser2': FieldValue.delete(),
          'reconciliationRequestedAt': FieldValue.delete(),
        });

        return null;
      });

      _isProcessing = false;
      notifyListeners();

      if (result == null && targetPartnerId != null) {
        // Intentamos actualizar la pareja si las reglas del servidor lo permiten
        try {
          await FirebaseFirestore.instance.collection('users').doc(targetPartnerId).update({'partnerId': myUid});
        } catch (_) {}
      }

      if (result == 'recovery_expired') {
        return 'El periodo de 72 horas para recuperar el vínculo ha expirado.';
      }
      if (result == 'already_relinked_with_someone_else') {
        return 'No se puede recuperar el vínculo porque uno de los dos ya se enlazó con otra pareja.';
      }

      if (result == null) {
        // Limpiamos las marcas de ex-pareja conservadas para esta pareja restaurada
        try {
          final conservedSnap = await FirebaseFirestore.instance
              .collection('memories')
              .where('coupleDocId', isEqualTo: coupleDocId)
              .where('isExCoupleConserved', isEqualTo: true)
              .get();

          final batch = FirebaseFirestore.instance.batch();
          for (final doc in conservedSnap.docs) {
            batch.update(doc.reference, {'isExCoupleConserved': FieldValue.delete()});
          }
          if (conservedSnap.docs.isNotEmpty) {
            await batch.commit();
          }
        } catch (_) {}
      }

      return null;
    } catch (e, stack) {
      debugPrint('Error al recuperar vínculo: $e\n$stack');
      _isProcessing = false;
      notifyListeners();
      return 'Error al recuperar el vínculo: $e';
    }
  }
  Future<String?> requestReconciliation(String coupleDocId) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;
      final docRef = FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId);
      final docSnap = await docRef.get();
      final data = docSnap.data();
      final String? rawUser1 = data?['user1Id'] ?? data?['user1'];
      String u1 = rawUser1 ?? '';
      if (u1.isEmpty) {
        final parts = coupleDocId.split('_');
        if (parts.isNotEmpty) u1 = parts[0];
      }
      final isUser1 = myUid == u1;

      await docRef.set({
        'reconciliationStatus': 'pending',
        'reconciliationRequestedBy': myUid,
        'reconciliationRequestedAt': FieldValue.serverTimestamp(),
        isUser1 ? 'reconciliationSignedUser1' : 'reconciliationSignedUser2': true,
      }, SetOptions(merge: true));

      _isProcessing = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Error al solicitar reconciliación: $e');
      _isProcessing = false;
      notifyListeners();
      return 'Error al enviar la propuesta de reconciliación.';
    }
  }

  /// Cancelar propuesta de reconciliación
  Future<String?> cancelReconciliation(String coupleDocId) async {
    _isProcessing = true;
    notifyListeners();

    try {
      await FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId).update({
        'reconciliationStatus': FieldValue.delete(),
        'reconciliationRequestedBy': FieldValue.delete(),
        'reconciliationRequestedAt': FieldValue.delete(),
      });

      _isProcessing = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Error al cancelar propuesta: $e');
      _isProcessing = false;
      notifyListeners();
      return 'Error al cancelar la propuesta.';
    }
  }

  /// Stream para obtener el progreso de pareja pausado dentro de las 72h (la desvinculación más reciente)
  Stream<DocumentSnapshot<Map<String, dynamic>>?> getPausedCoupleStream(String myUid) {
    final s1 = FirebaseFirestore.instance
        .collection('couples_progress')
        .where('user1Id', isEqualTo: myUid)
        .where('unlinkingState', isEqualTo: 'paused')
        .snapshots();

    final s2 = FirebaseFirestore.instance
        .collection('couples_progress')
        .where('user2Id', isEqualTo: myUid)
        .where('unlinkingState', isEqualTo: 'paused')
        .snapshots();

    final s3 = FirebaseFirestore.instance
        .collection('couples_progress')
        .where('user1', isEqualTo: myUid)
        .where('unlinkingState', isEqualTo: 'paused')
        .snapshots();

    final s4 = FirebaseFirestore.instance
        .collection('couples_progress')
        .where('user2', isEqualTo: myUid)
        .where('unlinkingState', isEqualTo: 'paused')
        .snapshots();

    return Rx.combineLatest4<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        DocumentSnapshot<Map<String, dynamic>>?>(s1, s2, s3, s4, (snap1, snap2, snap3, snap4) {
      if (_authProvider.userData?['partnerId'] != null) return null;

      final Map<String, DocumentSnapshot<Map<String, dynamic>>> mapDocs = {};
      for (final snap in [snap1, snap2, snap3, snap4]) {
        for (final doc in snap.docs) {
          mapDocs[doc.id] = doc;
        }
      }

      if (mapDocs.isEmpty) {
        _checkAndAutoLinkRestoredCouple(myUid);
        return null;
      }

      final now = DateTime.now();

      final validDocs = mapDocs.values.where((doc) {
        final data = doc.data();
        final recoveryEnd = (data?['recoveryWindowEnd'] as Timestamp?)?.toDate();
        if (recoveryEnd == null || now.isAfter(recoveryEnd)) return false;
        return true;
      }).toList();

      if (validDocs.isEmpty) return null;

      validDocs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aRecon = aData?['reconciliationStatus'] == 'pending';
        final bRecon = bData?['reconciliationStatus'] == 'pending';
        
        if (aRecon && !bRecon) return -1;
        if (bRecon && !aRecon) return 1;

        final tA = (aData?['unlinkedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tB = (bData?['unlinkedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tB.compareTo(tA);
      });

      return validDocs.first;
    }).asyncMap((pausedDoc) async {
      if (pausedDoc == null || !pausedDoc.exists) return null;

      final data = pausedDoc.data()!;
      final user1Id = (data['user1Id'] ?? data['user1']) as String?;
      final user2Id = (data['user2Id'] ?? data['user2']) as String?;
      final partnerId = myUid == user1Id ? user2Id : user1Id;
      final currentUnlinkedAt = (data['unlinkedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (partnerId == null) return null;

      try {
        // 1. Verificamos si la ex-pareja está vinculada actualmente con alguien más
        final partnerSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(partnerId)
            .get();

        if (partnerSnap.exists) {
          final partnerCurrentPartnerId = partnerSnap.data()?['partnerId'] as String?;
          if (partnerCurrentPartnerId != null && partnerCurrentPartnerId != myUid) {
            _finalizePausedDoc(pausedDoc.id);
            return null;
          }
        }

        // 2. Consultar TODAS las salas del ex-compañero para saber si tuvo una relación diferente
        final pSnaps = await Future.wait([
          FirebaseFirestore.instance.collection('couples_progress').where('user1Id', isEqualTo: partnerId).get(),
          FirebaseFirestore.instance.collection('couples_progress').where('user2Id', isEqualTo: partnerId).get(),
          FirebaseFirestore.instance.collection('couples_progress').where('user1', isEqualTo: partnerId).get(),
          FirebaseFirestore.instance.collection('couples_progress').where('user2', isEqualTo: partnerId).get(),
        ]);

        final Map<String, DocumentSnapshot<Map<String, dynamic>>> partnerMapDocs = {};
        for (final snap in pSnaps) {
          for (final doc in snap.docs) {
            partnerMapDocs[doc.id] = doc as DocumentSnapshot<Map<String, dynamic>>;
          }
        }

        for (final pDoc in partnerMapDocs.values) {
          if (pDoc.id == pausedDoc.id) continue;
          final pData = pDoc.data();
          if (pData == null) continue;

          final pUnlinkedAt = (pData['unlinkedAt'] as Timestamp?)?.toDate();
          final pVinculacion = (pData['fechaVinculacion'] as Timestamp?)?.toDate();

          // Si existe cualquier otra sala de pareja distinta con actividad posterior o previa desvinculación
          if (pDoc.id != pausedDoc.id) {
            if ((pUnlinkedAt != null && !pUnlinkedAt.isBefore(currentUnlinkedAt)) ||
                (pVinculacion != null && !pVinculacion.isBefore(currentUnlinkedAt)) ||
                pData['unlinkingState'] == 'paused') {
              _finalizePausedDoc(pausedDoc.id);
              return null;
            }
          }
        }
      } catch (e) {
        debugPrint('Error al verificar partner en pausedCoupleStream: $e');
      }

      return pausedDoc;
    });
  }

  /// Finaliza de forma definitiva una relación pausada antigua
  Future<void> _finalizePausedDoc(String coupleDocId) async {
    try {
      await FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId).update({
        'unlinkingState': 'finalized',
        'reconciliationStatus': FieldValue.delete(),
        'reconciliationRequestedBy': FieldValue.delete(),
        'reconciliationSignedUser1': FieldValue.delete(),
        'reconciliationSignedUser2': FieldValue.delete(),
        'reconciliationRequestedAt': FieldValue.delete(),
      });
    } catch (_) {}
  }

  void _checkAndAutoLinkRestoredCouple(String myUid) {
    if (_authProvider.userData?['partnerId'] != null) return;

    FirebaseFirestore.instance
        .collection('couples_progress')
        .where('user1Id', isEqualTo: myUid)
        .get()
        .then((snap) => _syncRestoredDocs(myUid, snap.docs));

    FirebaseFirestore.instance
        .collection('couples_progress')
        .where('user2Id', isEqualTo: myUid)
        .get()
        .then((snap) => _syncRestoredDocs(myUid, snap.docs));
  }

  void _syncRestoredDocs(String myUid, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (_authProvider.userData?['partnerId'] != null) return;
    for (final doc in docs) {
      final data = doc.data();
      final unlinkingState = data['unlinkingState'];
      final c1 = data['contractSignedUser1'] == true;
      final c2 = data['contractSignedUser2'] == true;
      if (unlinkingState == null && c1 && c2) {
        final u1 = (data['user1Id'] ?? data['user1']) as String?;
        final u2 = (data['user2Id'] ?? data['user2']) as String?;
        final partnerId = myUid == u1 ? u2 : u1;
        if (partnerId != null && partnerId.isNotEmpty) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(myUid)
              .update({'partnerId': partnerId});
          break;
        }
      }
    }
  }
}