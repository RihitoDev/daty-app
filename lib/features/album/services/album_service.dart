import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/album_memory.dart';

class AlbumService {
  
  // Stream para memorias SOLITARIAS en tiempo real
  static Stream<List<AlbumMemory>> soloMemoriesStream(String myUid) {
    return FirebaseFirestore.instance
        .collection('solo_memories')
        .where('userId', isEqualTo: myUid)
        .orderBy('timestamp', descending: true) // Ordenado desde Firestore
        .limit(50) // Paginación básica
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlbumMemory.fromSoloFirestore(doc.data()))
            .toList());
  }

  // Stream para memorias de PAREJA en tiempo real
  static Stream<List<AlbumMemory>> coupleMemoriesStream(String coupleDocId, String user1Name, String user2Name) {
    return FirebaseFirestore.instance
        .collection('memories')
        .where('coupleDocId', isEqualTo: coupleDocId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlbumMemory.fromCoupleFirestore(doc.data(), user1Name, user2Name))
            .toList());
  }

  // Stream para memorias GRUPALES en tiempo real (Consultando Subcolecciones)
  static Stream<List<AlbumMemory>> groupMemoriesStream(String myUid) async* {
    // 1. Obtener los grupos del usuario
    final groupsSnapshot = await FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: myUid)
        .get();

    // 2. Si no está en ningún grupo, emitir lista vacía
    if (groupsSnapshot.docs.isEmpty) {
      yield [];
      return;
    }

    // 3. Crear streams para la subcolección 'memories' de CADA grupo
    List<Stream<List<AlbumMemory>>> groupStreams = groupsSnapshot.docs.map((groupDoc) {
      return FirebaseFirestore.instance
          .collection('groups')
          .doc(groupDoc.id)
          .collection('memories')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .map((memSnapshot) => memSnapshot.docs
              .map((memDoc) => AlbumMemory.fromGroupFirestore(memDoc.data()))
              .toList());
    }).toList();

    // 4. Combinar los streams (usando un enfoque simple)
    // Nota: Para una app muy grande, convendría usar RxDart, pero esto funciona bien.
    for (var stream in groupStreams) {
      await for (var memories in stream) {
        // Como estamos escuchando varios streams, recolectamos lo que vamos recibiendo
        // Para hacerlo sencillo y no bloquear, simplemente emitimos lo que llega.
        // Para tener TODOS juntos, es mejor usar un Provider que una las listas.
        yield memories; 
      }
    }
  }

  // Método para obtener TODAS las memorias (Para la pestaña general)
  static Future<List<AlbumMemory>> fetchAllMemories({
    required String myUid,
    required String myName,
    required String? partnerId,
    required String partnerName,
    required bool isUser1,
  }) async {
    List<AlbumMemory> tempMemories = [];

    try {
      final soloSnap = await FirebaseFirestore.instance
          .collection('solo_memories')
          .where('userId', isEqualTo: myUid)
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();
      for (var doc in soloSnap.docs) {
        tempMemories.add(AlbumMemory.fromSoloFirestore(doc.data()));
      }
    } catch (e) {
      debugPrint('Error fetching solo memories: $e');
    }

    if (partnerId != null) {
      try {
        String coupleDocId = isUser1 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';
        String user1Name = isUser1 ? myName : partnerName;
        String user2Name = isUser1 ? partnerName : myName;
        
        final coupleSnap = await FirebaseFirestore.instance
            .collection('memories')
            .where('coupleDocId', isEqualTo: coupleDocId)
            .orderBy('timestamp', descending: true)
            .limit(30)
            .get();
            
        for (var doc in coupleSnap.docs) {
          tempMemories.add(AlbumMemory.fromCoupleFirestore(doc.data(), user1Name, user2Name));
        }
      } catch (e) {
        debugPrint('Error fetching couple memories: $e');
      }
    }

    try {
      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: myUid)
          .get();

      for (var groupDoc in groupsSnapshot.docs) {
        final memSnapshot = await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupDoc.id)
            .collection('memories')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();
            
        for (var memDoc in memSnapshot.docs) {
          tempMemories.add(AlbumMemory.fromGroupFirestore(memDoc.data()));
        }
      }
    } catch (e) {
      debugPrint('Error fetching group memories: $e');
    }

    tempMemories.sort((a, b) => b.date.compareTo(a.date));

    return tempMemories;
  }
}