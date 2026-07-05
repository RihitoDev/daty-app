import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Operaciones de Firebase puras para el mapa de aventuras.
/// Separadas del widget para poder probarlas y reutilizarlas sin depender de la UI.
class MapDataService {

  /// Genera el ID compuesto de la pareja ordenando UIDs alfabéticamente
  static String? buildCoupleDocId(String myUid, String? partnerId) {
    if (partnerId == null) return null;
    return myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';
  }

  /// Referencia al documento de progreso según el modo de juego
  static DocumentReference? getProgressDocRef({
    required String mode,
    required String myUid,
    String? coupleDocId,
  }) {
    if (mode == 'solo') {
      return FirebaseFirestore.instance.collection('solo_progress').doc(myUid);
    } else if (mode == 'couple' && coupleDocId != null) {
      return FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId);
    }
    return null;
  }

  /// Descarga todas las aventuras del modo dado para la caché local
  static Future<Map<int, Map<String, dynamic>>> fetchAdventureCache(String mode) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('adventures')
        .where('type', isEqualTo: mode == 'solo' ? 'solo' : 'pareja')
        .get()
        .timeout(const Duration(seconds: 10));

    Map<int, Map<String, dynamic>> cache = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('number')) {
        cache[data['number']] = data;
      }
    }
    return cache;
  }

  /// Trae las calificaciones de las aventuras completadas en el camino.
  /// Firestore whereIn limita a 30, así que procesamos por tandas.
  static Future<Map<int, double>> fetchRatings({
    required String mode,
    required List<int> adventurePath,
    String? myUid,
    String? coupleDocId,
  }) async {
    if (adventurePath.isEmpty) return {};
    Map<int, double> ratings = {};

    List<List<int>> chunks = [];
    for (var i = 0; i < adventurePath.length; i += 30) {
      chunks.add(adventurePath.sublist(i, min(i + 30, adventurePath.length)));
    }

    for (var chunk in chunks) {
      if (mode == 'solo' && myUid != null) {
        List<String> docIds = chunk.map((id) => '${myUid}_$id').toList();
        final snap = await FirebaseFirestore.instance
            .collection('solo_memories')
            .where(FieldPath.documentId, whereIn: docIds)
            .get();
        for (var doc in snap.docs) {
          final d = doc.data();
          int advId = d['id_adventure'] is int ? d['id_adventure'] : int.parse(d['id_adventure'].toString());
          int r = d['rating'] ?? 0;
          if (r > 0) ratings[advId] = r.toDouble();
        }
      } else if (mode == 'couple' && coupleDocId != null) {
        List<String> docIds = chunk.map((id) => '${coupleDocId}_$id').toList();
        final snap = await FirebaseFirestore.instance
            .collection('memories')
            .where(FieldPath.documentId, whereIn: docIds)
            .get();
        for (var doc in snap.docs) {
          final d = doc.data();
          int advId = d['id_adventure'] is int ? d['id_adventure'] : int.parse(d['id_adventure'].toString());
          int r1 = d['user1_rating'] ?? 0;
          int r2 = d['user2_rating'] ?? 0;
          if (r1 > 0 && r2 > 0) {
            ratings[advId] = (r1 + r2) / 2.0;
          } else if (r1 > 0) {
            ratings[advId] = r1.toDouble();
          } else if (r2 > 0) {
            ratings[advId] = r2.toDouble();
          }
        }
      }
    }
    return ratings;
  }

  /// Marca una aventura como activa o la desactiva al terminar
  static Future<bool> setAdventureStatus({
    required String mode,
    required String myUid,
    String? coupleDocId,
    required int adventureNumber,
    required bool isActive,
  }) async {
    try {
      if (mode == 'solo') {
        final ref = FirebaseFirestore.instance.collection('solo_progress').doc(myUid);
        if (isActive) {
          await ref.set({'activeAdventureNumber': adventureNumber}, SetOptions(merge: true));
        } else {
          await ref.update({'activeAdventureNumber': FieldValue.delete()}).catchError((_) => null);
        }
      } else if (coupleDocId != null) {
        final ref = FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId);
        if (isActive) {
          await ref.set({
            'activeAdventureNumber': adventureNumber,
            'reviewCompletedUser1': false,
            'reviewCompletedUser2': false,
          }, SetOptions(merge: true));
        } else {
          await ref.update({
            'activeAdventureNumber': FieldValue.delete(),
            'reviewCompletedUser1': false,
            'reviewCompletedUser2': false,
          }).catchError((_) => null);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error setting adventure status: $e');
      return false;
    }
  }

  /// Genera el siguiente nodo aleatorio que no esté ya en el camino
  static Future<void> generateNextNode({
    required String mode,
    required String myUid,
    String? coupleDocId,
    required Map<int, Map<String, dynamic>> adventuresCache,
    required List<int> adventurePath,
  }) async {
    if (adventuresCache.isEmpty) return;
    List<int> available = adventuresCache.keys.where((id) => !adventurePath.contains(id)).toList();
    if (available.isEmpty) return;

    int nextId = available[Random().nextInt(available.length)];

    try {
      String collection = mode == 'solo' ? 'solo_progress' : 'couples_progress';
      String docId = mode == 'solo' ? myUid : coupleDocId!;
      if (docId.isEmpty) return;
      await FirebaseFirestore.instance.collection(collection).doc(docId).set({
        'adventurePath': FieldValue.arrayUnion([nextId])
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error generating next node: $e');
    }
  }

  /// Cambia la aventura de un nodo (máx. 2 rerolls, usa transacción)
  static Future<bool> rerollAdventure({
    required String mode,
    required String myUid,
    String? coupleDocId,
    required Map<int, Map<String, dynamic>> adventuresCache,
    required int nodeIndex,
    required int currentAdventureId,
  }) async {
    DocumentReference? docRef = getProgressDocRef(mode: mode, myUid: myUid, coupleDocId: coupleDocId);
    if (docRef == null) return false;

    try {
      bool rerolled = false;
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>;
        int rerollsUsed = data['rerollsUsed'] ?? 0;
        List<dynamic> skipped = List.from(data['skippedAdventures'] ?? []);
        List<dynamic> path = List.from(data['adventurePath'] ?? []);

        if (rerollsUsed >= 2) return;

        List<int> allIds = adventuresCache.keys.toList();
        List<int> available = allIds.where((id) => !path.contains(id) || id == currentAdventureId).toList();
        available.removeWhere((id) => skipped.contains(id));
        if (available.isEmpty) return;

        int newId = available[Random().nextInt(available.length)];
        path[nodeIndex] = newId;
        skipped.add(currentAdventureId);

        transaction.update(docRef, {
          'adventurePath': path,
          'rerollsUsed': rerollsUsed + 1,
          'skippedAdventures': skipped,
        });
        rerolled = true;
      });
      return rerolled;
    } catch (e) {
      debugPrint('Error rerolling adventure: $e');
      return false;
    }
  }
}