import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsProvider extends ChangeNotifier {
  final AuthProvider _authProvider;

  bool _isUnlinking = false;
  bool get isUnlinking => _isUnlinking;

  SettingsProvider(this._authProvider);

  Future<String?> resetSoloProgress() async {
    _isUnlinking = true; // Reutilizamos el loader
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;

      // 1. Borramos el documento de progreso
      await FirebaseFirestore.instance.collection('solo_progress').doc(myUid).delete();

      // 2. Borramos todos los recuerdos solitarios de este usuario
      final memoriesQuery = await FirebaseFirestore.instance
          .collection('solo_memories')
          .where('userId', isEqualTo: myUid) // Aseguraremos guardar esto en la review
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in memoriesQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      _isUnlinking = false;
      notifyListeners();
      return null; // Éxito
    } catch (e) {
      debugPrint('Error al borrar progreso solitario: $e');
      _isUnlinking = false;
      notifyListeners();
      return 'Error al reiniciar progreso. Inténtalo de nuevo.';
    }
  }

  Future<String?> unlinkPartner() async {
    _isUnlinking = true;
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

      // Transacción para borrar todo rastro del vínculo
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
        final partnerRef = FirebaseFirestore.instance.collection('users').doc(partnerId);
        final coupleRef = FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId);

        // 1. Eliminar partnerId de mi usuario
        transaction.update(myRef, {'partnerId': FieldValue.delete()});
        
        // 2. Eliminar partnerId del usuario de mi pareja
        transaction.update(partnerRef, {'partnerId': FieldValue.delete()});
        
        // 3. Eliminar el documento de progreso de pareja
        transaction.delete(coupleRef);
      });

      _isUnlinking = false;
      notifyListeners();
      return null; // Éxito
    } catch (e) {
      debugPrint('Error al desvincular: $e');
      _isUnlinking = false;
      notifyListeners();
      return 'Error al desvincular. Inténtalo de nuevo.';
    }
  }
  
}