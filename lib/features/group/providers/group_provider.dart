import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<String?> createGroup() async {
    _isLoading = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;
      final code = _generateGroupCode();

      // Inicializamos el doc del grupo, nos asignamos como creador y abrimos la sala en modo espera
      await FirebaseFirestore.instance.collection('groups').doc(code).set({
        'code': code,
        'creatorId': myUid,
        'members': [myUid],
        'maxMembers': 12,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _currentGroupCode = code;
      _isLoading = false;
      notifyListeners();
      return code;
    } catch (e) {
      debugPrint('Fallo al armar el grupo en Firebase: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> joinGroup(String code) async {
    _isLoading = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;
      final docRef = FirebaseFirestore.instance.collection('groups').doc(code.toUpperCase());
      final docSnap = await docRef.get();

      // Filtros clave antes de dejar entrar a alguien a la sala para evitar bugs visuales o sobrecupos
      if (!docSnap.exists) return 'El código no existe';
      if (docSnap.data()!['status'] != 'waiting') return 'La partida ya comenzó';

      List<dynamic> members = docSnap.data()!['members'] ?? [];
      int maxMembers = docSnap.data()!['maxMembers'] ?? 12;
      
      if (members.contains(myUid)) return 'Ya estás en este grupo';
      if (members.length >= maxMembers) return 'El grupo está lleno (Máx. $maxMembers)';

      await docRef.update({'members': FieldValue.arrayUnion([myUid])});
      
      _currentGroupCode = code.toUpperCase();
      _isLoading = false;
      notifyListeners();
      return null; 
    } catch (e) {
      debugPrint('Rebote al intentar unirse a la sala: $e');
      _isLoading = false;
      notifyListeners();
      return 'Error al unirse al grupo';
    }
  }

  Future<void> updateMaxMembers(String groupCode, int newMax) async {
    try {
      await FirebaseFirestore.instance.collection('groups').doc(groupCode).update({'maxMembers': newMax});
    } catch (e) {
      debugPrint('Fallo al cambiar el límite de integrantes: $e');
    }
  }

  Future<Map<String, dynamic>?> startExpedition(String groupCode) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('adventures').where('type', isEqualTo: 'grupo').get();
      if (snapshot.docs.isEmpty) return null;

      // Sorteamos una aventura aleatoria del pool de grupos y bloqueamos la sala para que no entre nadie más
      final randomIndex = Random().nextInt(snapshot.docs.length);
      final adventureData = snapshot.docs[randomIndex].data();

      await FirebaseFirestore.instance.collection('groups').doc(groupCode).update({
        'status': 'active',
        'activeAdventureId': adventureData['number'],
      });

      return adventureData;
    } catch (e) {
      debugPrint('Fallo al dar el pitazo de salida: $e');
      return null;
    }
  }

  Future<void> leaveGroup() async {
    if (_currentGroupCode == null) return;
    final myUid = _authProvider.user!.uid;
    final docRef = FirebaseFirestore.instance.collection('groups').doc(_currentGroupCode!);

    try {
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        List<dynamic> members = docSnap.data()!['members'];
        
        // Si somos el último en salir, apagamos la luz y borramos el grupo de la BD. 
        // Si no, nos borramos del array y le pasamos la batuta de creador al siguiente en la lista.
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
      debugPrint('Problema al intentar abandonar la sala: $e');
    } finally {
      _currentGroupCode = null;
      _groupSubscription?.cancel();
      notifyListeners();
    }
  }

  String _generateGroupCode() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    final rnd = Random();
    
    String code = '';
    for (int i = 0; i < 3; i++) { code += letters[rnd.nextInt(letters.length)]; }
    for (int i = 0; i < 3; i++) { code += numbers[rnd.nextInt(numbers.length)]; }
    
    return code;
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    super.dispose();
  }
}