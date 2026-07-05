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

  // ─── Crear grupo (sin cambios drásticos, ya que escribe un doc nuevo) ───
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

  // ─── Unirse al grupo — TRANSACCIÓN que lee + valida + escribe atómicamente ───
  Future<String?> joinGroup(String code) async {
    _isLoading = true;
    notifyListeners();

    final myUid = _authProvider.user!.uid;
    final docRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(code.toUpperCase());

    try {
      // ── Firestore Transaction: todo se ejecuta en el servidor de forma atómica ──
      final result = await FirebaseFirestore.instance.runTransaction<String?>(
        (transaction) async {
          final docSnap = await transaction.get(docRef);

          if (!docSnap.exists) return 'El código no existe';

          final data = docSnap.data()!;
          if (data['status'] != 'waiting') return 'La partida ya comenzó';

          final List<dynamic> members = List<dynamic>.from(data['members'] ?? []);
          final int maxMembers = (data['maxMembers'] as int?) ?? 12;

          if (members.contains(myUid)) return 'Ya estás en este grupo';
          if (members.length >= maxMembers) {
            return 'El grupo está lleno (Máx. $maxMembers)';
          }

          // Todo validó → escribimos dentro de la misma transacción.
          // Si otro miembro se unió entre nuestro get y este punto,
          // Firestore re-ejecuta la transacción automáticamente (hasta 5 intentos).
          transaction.update(docRef, {
            'members': FieldValue.arrayUnion([myUid]),
          });

          return null; // null = éxito, sin error
        },
      );

      if (result == null) {
        // Éxito
        _currentGroupCode = code.toUpperCase();
      }

      _isLoading = false;
      notifyListeners();
      return result; // null si todo ok, string con el mensaje de error si falló
    } catch (e) {
      debugPrint('Rebote al intentar unirse a la sala: $e');
      _isLoading = false;
      notifyListeners();
      return 'Error al unirse al grupo';
    }
  }

  // ─── Cambiar límite de miembros (sin cambios, es una operación simple) ───
  Future<void> updateMaxMembers(String groupCode, int newMax) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupCode)
          .update({'maxMembers': newMax});
    } catch (e) {
      debugPrint('Fallo al cambiar el límite de integrantes: $e');
    }
  }

  // ─── Iniciar expedición — TRANSACCIÓN + validación de aventura antes de cambiar estado ───
  Future<Map<String, dynamic>?> startExpedition(String groupCode) async {
    final groupRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupCode);

    try {
      // 1) Primero verificamos que existan aventuras grupales disponibles
      final adventureSnap = await FirebaseFirestore.instance
          .collection('adventures')
          .where('type', isEqualTo: 'grupo')
          .get();

      if (adventureSnap.docs.isEmpty) return null;

      // 2) Sorteo de aventura
      final randomIndex = Random().nextInt(adventureSnap.docs.length);
      final adventureData = adventureSnap.docs[randomIndex].data();

      // 3) Transacción: cambiamos status SOLO si sigue en 'waiting' y hay >= 2 miembros
      final success = await FirebaseFirestore.instance.runTransaction<bool>(
        (transaction) async {
          final groupSnap = await transaction.get(groupRef);
          if (!groupSnap.exists) return false;

          final data = groupSnap.data()!;
          if (data['status'] != 'waiting') return false;

          final members = List<dynamic>.from(data['members'] ?? []);
          if (members.length < 2) return false;

          // Todo ok → actualizamos atómicamente
          transaction.update(groupRef, {
            'status': 'active',
            'activeAdventureId': adventureData['number'],
          });
          return true;
        },
      );

      // Si la transacción no se completó (ej. otro ya la inició o muy pocos miembros),
      // devolvemos null para que el UI no navegue.
      return success ? adventureData : null;
    } catch (e) {
      debugPrint('Fallo al dar el pitazo de salida: $e');
      return null;
    }
  }

  // ─── Abandonar grupo — TRANSACCIÓN para evitar lecturas/escrituras desincronizadas ───
  Future<void> leaveGroup() async {
    if (_currentGroupCode == null) return;
    final myUid = _authProvider.user!.uid;
    final docRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(_currentGroupCode!);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docSnap = await transaction.get(docRef);
        if (!docSnap.exists) return; // Ya no existe, nada que hacer

        final data = docSnap.data()!;
        final List<dynamic> members = List<dynamic>.from(data['members'] ?? []);

        if (members.length <= 1 && members.contains(myUid)) {
          // Soy el último → borramos el grupo entero de forma atómica
          transaction.delete(docRef);
        } else if (members.contains(myUid)) {
          // Hay más gente → me quito y, si era creador, transfiero la batuta
          final batchOps = <String, dynamic>{};
          batchOps['members'] = FieldValue.arrayRemove([myUid]);

          if (data['creatorId'] == myUid) {
            // Buscamos el siguiente miembro válido que NO sea yo
            final nextCreator = members.cast<String>().firstWhere(
              (m) => m != myUid,
              orElse: () => '',
            );
            if (nextCreator.isNotEmpty) {
              batchOps['creatorId'] = nextCreator;
            }
          }

          transaction.update(docRef, batchOps);
        }
        // Si no estoy en la lista (caso raro), no hacemos nada
      });
    } catch (e) {
      debugPrint('Problema al intentar abandonar la sala: $e');
    } finally {
      _currentGroupCode = null;
      _groupSubscription?.cancel();
      _groupSubscription = null;
      notifyListeners();
    }
  }

  // ─── Generador de código alfanumérico (sin cambios) ───
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