import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsProvider with ChangeNotifier {
  final AuthProvider _authProvider;

  bool _isProcessing = false; 
  bool get isProcessing => _isProcessing;

  SettingsProvider(this._authProvider);

  Future<String?> resetSoloProgress() async {
    _isProcessing = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;

      // Borramos el documento principal del progreso
      await FirebaseFirestore.instance.collection('solo_progress').doc(myUid).delete();

      // Borramos todos los recuerdos de golpe usando un batch para no hacer peticiones una por una
      final memoriesQuery = await FirebaseFirestore.instance
          .collection('solo_memories')
          .where('userId', isEqualTo: myUid)
          .get();

      if (memoriesQuery.docs.isNotEmpty) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in memoriesQuery.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      _isProcessing = false;
      notifyListeners();
      return null; 
    } catch (e) {
      debugPrint('Error al borrar progreso solitario: $e');
      _isProcessing = false;
      notifyListeners();
      return 'Error al reiniciar progreso. Inténtalo de nuevo.';
    }
  }

    Future<String?> unlinkPartner() async {
    _isProcessing = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;

      // Usamos transacción para leer el estado real desde el servidor
      final myDocRef = FirebaseFirestore.instance.collection('users').doc(myUid);

      final result = await FirebaseFirestore.instance.runTransaction((transaction) async {
        final myDoc = await transaction.get(myDocRef);
        final partnerId = myDoc.data()?['partnerId'] as String?;

        // Verificamos en el servidor que todavía tenga pareja
        if (partnerId == null) return 'unlink_no_partner';

        final partnerRef = FirebaseFirestore.instance.collection('users').doc(partnerId);
        final partnerDoc = await transaction.get(partnerRef);

        String coupleDocId = myUid.compareTo(partnerId) < 0 
            ? '${myUid}_$partnerId' 
            : '${partnerId}_$myUid';

        final coupleRef = FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId);

        // Desvinculamos a ambos y borramos el doc de pareja en la misma transacción
        transaction.update(myDocRef, {'partnerId': null});
        // Solo actualizamos a la pareja si todavía estamos vinculados a ella
        if (partnerDoc.exists && partnerDoc.data()?['partnerId'] == myUid) {
          transaction.update(partnerRef, {'partnerId': null});
        }
        transaction.delete(coupleRef);

        return null; // éxito
      });

      if (result == 'unlink_no_partner') {
        _isProcessing = false;
        notifyListeners();
        return null; // Ya no tiene pareja, no es un error, simplemente ya está desvinculado
      }

      // Las memorias se borran fuera de la transacción porque podrían ser muchas
      // y WriteBatch tiene límite de 500 ops.
      // Se borran con chunked batches.
      await _deleteCoupleMemoriesSafe(myUid);

      _isProcessing = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Error al desvincular (detalles): $e');
      _isProcessing = false;
      notifyListeners();
      return 'Error al desvincular. Inténtalo de nuevo.';
    }
  }

  // Borra memorias en lotes de hasta 400 para no pasar el límite de 500 de WriteBatch
  Future<void> _deleteCoupleMemoriesSafe(String myUid) async {
    final String? partnerId = _authProvider.userData?['partnerId']; // puede ser null ya si la transacción pasó
    if (partnerId == null) return;

    String coupleDocId = myUid.compareTo(partnerId) < 0 
        ? '${myUid}_$partnerId' 
        : '${partnerId}_$myUid';

    bool hasMore = true;
    while (hasMore) {
      final snapshot = await FirebaseFirestore.instance
          .collection('memories')
          .where('coupleDocId', isEqualTo: coupleDocId)
          .limit(400)
          .get();

      if (snapshot.docs.isEmpty) {
        hasMore = false;
        break;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Si trajo menos de 400, ya no hay más
      hasMore = snapshot.docs.length >= 400;
    }
  }
}