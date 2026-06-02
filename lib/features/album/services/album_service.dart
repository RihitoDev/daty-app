import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/album_memory.dart';

class AlbumService {
  
  static Stream<List<AlbumMemory>> soloMemoriesStream(String myUid) {
    return FirebaseFirestore.instance
        .collection('solo_memories')
        .where('userId', isEqualTo: myUid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlbumMemory.fromSoloFirestore(doc.data()))
            .toList())
        .handleError((error) {
          debugPrint('❌ ERROR EN SOLO STREAM: $error');
          return [];
        });
  }

  static Stream<List<AlbumMemory>> coupleMemoriesStream(String coupleDocId, String user1Name, String user2Name) {
    return FirebaseFirestore.instance
        .collection('memories')
        .where('coupleDocId', isEqualTo: coupleDocId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlbumMemory.fromCoupleFirestore(doc.data(), user1Name, user2Name))
            .toList())
        .handleError((error) {
          debugPrint('❌ ERROR EN COUPLE STREAM: $error');
          return [];
        });
  }

  // SOLUCIÓN: Ahora solo busca las memorias que el usuario decidió guardar en su perfil
  static Stream<List<AlbumMemory>> groupMemoriesStream(String myUid) {
    // 1. Escuchamos los cambios en el perfil del usuario (para saber si guarda/ignora algo nuevo)
    return FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .snapshots()
        .asyncExpand((userSnap) {
          
      final List<dynamic> savedIds = userSnap.data()?['savedGroupMemories'] ?? [];
      
      // Si no hay memorias guardadas, devolvemos una lista vacía inmediatamente
      if (savedIds.isEmpty) {
        return Stream.value([]);
      }

      // 2. Si hay memorias guardadas, buscamos SOLO esos documentos
      // Nota: whereIn tiene un límite de 30 elementos en Firestore, suficiente para un álbum
      return FirebaseFirestore.instance
          .collection('group_memories')
          .where(FieldPath.documentId, whereIn: savedIds)
          .snapshots()
          .map((snapshot) {
            final list = snapshot.docs
                .map((doc) => AlbumMemory.fromGroupFirestore(doc.data()))
                .toList();
            
            // Ordenamos en Dart para evitar requerir otro índice compuesto en Firebase
            list.sort((a, b) => b.date.compareTo(a.date));
            return list;
          })
          .handleError((error) {
            debugPrint('❌ ERROR EN GROUP STREAM: $error');
            return [];
          });
    });
  }
}