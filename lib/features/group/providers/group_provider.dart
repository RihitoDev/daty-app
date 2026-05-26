import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'dart:math';

class GroupProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  
  bool _isLoading = false;
  String? _currentGroupCode;
  StreamSubscription? _groupSubscription;

  bool get isLoading => _isLoading;
  String? get currentGroupCode => _currentGroupCode;

  GroupProvider(this._authProvider);

  // ==========================================
  // CREAR LOBBY GRUPAL (Límite 12 por defecto)
  // ==========================================
  Future<String?> createGroup() async {
    _isLoading = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;
      final code = _generateGroupCode();

      await FirebaseFirestore.instance.collection('groups').doc(code).set({
        'code': code,
        'creatorId': myUid,
        'members': [myUid],
        'maxMembers': 12, // ✅ CAMBIO: Límite por defecto ahora es 12
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _currentGroupCode = code;
      _isLoading = false;
      notifyListeners();
      return code;
    } catch (e) {
      debugPrint('Error al crear grupo: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ==========================================
  // UNIRSE A LOBBY GRUPAL
  // ==========================================
  Future<String?> joinGroup(String code) async {
    _isLoading = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;
      final docRef = FirebaseFirestore.instance.collection('groups').doc(code.toUpperCase());
      final docSnap = await docRef.get();

      if (!docSnap.exists) return 'El código no existe';
      if (docSnap.data()!['status'] != 'waiting') return 'La partida ya comenzó';

      List<dynamic> members = docSnap.data()!['members'] ?? [];
      int maxMembers = docSnap.data()!['maxMembers'] ?? 12; // ✅ CAMBIO: Lee 12 por defecto
      
      if (members.contains(myUid)) return 'Ya estás en este grupo';
      if (members.length >= maxMembers) return 'El grupo está lleno (Máx. $maxMembers)';

      await docRef.update({'members': FieldValue.arrayUnion([myUid])});
      
      _currentGroupCode = code.toUpperCase();
      _isLoading = false;
      notifyListeners();
      return null; 
    } catch (e) {
      debugPrint('Error al unirse: $e');
      _isLoading = false;
      notifyListeners();
      return 'Error al unirse al grupo';
    }
  }

  // ==========================================
  // ACTUALIZAR LÍMITE DE MIEMBROS
  // ==========================================
  Future<void> updateMaxMembers(String groupCode, int newMax) async {
    try {
      await FirebaseFirestore.instance.collection('groups').doc(groupCode).update({
        'maxMembers': newMax,
      });
    } catch (e) {
      debugPrint('Error al actualizar límite: $e');
    }
  }

  // ==========================================
  // INICIAR EXPEDICIÓN (Aleatoria)
  // ==========================================
  Future<Map<String, dynamic>?> startExpedition(String groupCode) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('adventures').get();
      if (snapshot.docs.isEmpty) return null;

      final randomIndex = Random().nextInt(snapshot.docs.length);
      final adventureData = snapshot.docs[randomIndex].data();

      await FirebaseFirestore.instance.collection('groups').doc(groupCode).update({
        'status': 'active',
        'activeAdventureId': adventureData['number'],
      });

      return adventureData;
    } catch (e) {
      debugPrint('Error al iniciar expedición: $e');
      return null;
    }
  }

  // ==========================================
  // SALIRSE DEL LOBBY
  // ==========================================
  Future<void> leaveGroup() async {
    if (_currentGroupCode == null) return;
    final myUid = _authProvider.user!.uid;
    final docRef = FirebaseFirestore.instance.collection('groups').doc(_currentGroupCode!);

    try {
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        List<dynamic> members = docSnap.data()!['members'];
        if (members.length <= 1) {
          await docRef.delete();
        } else {
          await docRef.update({'members': FieldValue.arrayRemove([myUid])});
          if (docSnap.data()!['creatorId'] == myUid) {
            await docRef.update({'creatorId': members.firstWhere((m) => m != myUid)});
          }
        }
      }
    } catch (e) {
      debugPrint('Error al salir del grupo: $e');
    } finally {
      _currentGroupCode = null;
      _groupSubscription?.cancel();
      notifyListeners();
    }
  }

  // ✅ CAMBIO: Generador de 3 letras y 3 números (Ej: ABC123)
  String _generateGroupCode() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    final rnd = Random();
    
    String code = '';
    // 3 letras
    for (int i = 0; i < 3; i++) {
      code += letters[rnd.nextInt(letters.length)];
    }
    // 3 números
    for (int i = 0; i < 3; i++) {
      code += numbers[rnd.nextInt(numbers.length)];
    }
    
    return code;
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }
}