import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/album_memory.dart';

class AlbumService {
  
  static Stream<List<AlbumMemory>> soloMemoriesStream(String myUid) {
    // Traemos las aventuras en solitario y limitamos a 50 para no reventar las lecturas en Firebase
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
          debugPrint('Fallo al leer la colección solo_memories: $error');
          return <AlbumMemory>[];
        });
  }

  static Stream<List<AlbumMemory>> coupleMemoriesStream(String coupleDocId, String user1Name, String user2Name) {
    // Filtramos directo por el ID del documento de la pareja
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
          debugPrint('Fallo al leer la colección de pareja: $error');
          return <AlbumMemory>[];
        });
  }

  static Stream<List<AlbumMemory>> groupMemoriesStream(String myUid) {
    // Primero escuchamos el doc del usuario para sacar la lista de IDs de los recuerdos grupales
    return FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .snapshots()
        .asyncExpand((userSnap) {
          
      final List<dynamic> savedIds = userSnap.data()?['savedGroupMemories'] ?? [];
      
      if (savedIds.isEmpty) {
        return Stream.value([]);
      }

      // Consultamos los documentos específicos que guardó el usuario.
      // Ojo: whereIn en Firestore soporta máximo 10 elementos. Si guardan más, tocará paginar o cambiar la lógica.
      return FirebaseFirestore.instance
          .collection('group_memories')
          .where(FieldPath.documentId, whereIn: savedIds)
          .snapshots()
          .map((snapshot) {
            final list = snapshot.docs
                .map((doc) => AlbumMemory.fromGroupFirestore(doc.data()))
                .toList();
            
            // Ordenamos en local porque whereIn te los devuelve en cualquier orden
            list.sort((a, b) => b.date.compareTo(a.date));
            return list;
          })
          .handleError((error) {
            debugPrint('Fallo en el stream de grupo (revisa si pasaste de los 10 items en whereIn): $error');
            return <AlbumMemory>[];
          });
    });
  }
}