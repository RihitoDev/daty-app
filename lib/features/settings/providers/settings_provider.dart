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

      await FirebaseFirestore.instance.collection('solo_progress').doc(myUid).delete();

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
      final String? partnerId = _authProvider.userData?['partnerId'];

      if (partnerId == null) {
        throw Exception("No tienes pareja vinculada");
      }

      String coupleDocId = myUid.compareTo(partnerId) < 0 
          ? '${myUid}_$partnerId' 
          : '${partnerId}_$myUid';

      final memoriesQuery = await FirebaseFirestore.instance
          .collection('memories')
          .where('coupleDocId', isEqualTo: coupleDocId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in memoriesQuery.docs) {
        batch.delete(doc.reference);
      }

      final myRef = FirebaseFirestore.instance.collection('users').doc(myUid);
      final partnerRef = FirebaseFirestore.instance.collection('users').doc(partnerId);
      final coupleRef = FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId);

      batch.update(myRef, {'partnerId': null});
      batch.update(partnerRef, {'partnerId': null});
      batch.delete(coupleRef);

      await batch.commit();

      _isProcessing = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint(' Error al desvincular (detalles): $e');
      _isProcessing = false;
      notifyListeners();
      return 'Error al desvincular. Revisa la consola para ver el error de permisos.';
    }
  }
}