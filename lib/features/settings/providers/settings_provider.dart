import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsProvider extends ChangeNotifier {
  final AuthProvider _authProvider;

  bool _isProcessing = false; // CAMBIO: Renombrado para cubrir ambas acciones
  bool get isProcessing => _isProcessing;

  SettingsProvider(this._authProvider);

  Future<String?> resetSoloProgress() async {
    _isProcessing = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;

      // 1. Borramos el documento de progreso
      await FirebaseFirestore.instance.collection('solo_progress').doc(myUid).delete();

      // 2. Borramos todos los recuerdos solitarios de este usuario
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
      return null; // Éxito
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
      final String? partnerId = _authProvider.userData?['partnerId'];

      if (partnerId == null) {
        throw Exception("No tienes pareja vinculada");
      }

      String coupleDocId = myUid.compareTo(partnerId) < 0 
          ? '${myUid}_$partnerId' 
          : '${partnerId}_$myUid';

      // 1. Eliminar los documentos de recuerdos de pareja (Memories)
      final memoriesQuery = await FirebaseFirestore.instance
          .collection('memories')
          .where('coupleDocId', isEqualTo: coupleDocId)
          .get();

      if (memoriesQuery.docs.isNotEmpty) {
        WriteBatch memoriesBatch = FirebaseFirestore.instance.batch();
        for (var doc in memoriesQuery.docs) {
          memoriesBatch.delete(doc.reference);
        }
        await memoriesBatch.commit();
      }

      // 2. Transacción para borrar el vínculo y el progreso
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
        final partnerRef = FirebaseFirestore.instance.collection('users').doc(partnerId);
        final coupleRef = FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId);

        transaction.update(myRef, {'partnerId': FieldValue.delete()});
        transaction.update(partnerRef, {'partnerId': FieldValue.delete()});
        transaction.delete(coupleRef);
      });

      _isProcessing = false;
      notifyListeners();
      return null; // Éxito
    } catch (e) {
      debugPrint('Error al desvincular: $e');
      _isProcessing = false;
      notifyListeners();
      return 'Error al desvincular. Inténtalo de nuevo.';
    }
  }
}