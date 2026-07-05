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
          debugPrint('Fallo al leer la colección solo_memories: $error');
          return <AlbumMemory>[];
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
          debugPrint('Fallo al leer la colección de pareja: $error');
          return <AlbumMemory>[];
        });
  }

  static Stream<List<AlbumMemory>> groupMemoriesStream(String myUid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .snapshots()
        .asyncExpand((userSnap) async* {
      
      final List<dynamic> savedIds = userSnap.data()?['savedGroupMemories'] ?? [];
      
      if (savedIds.isEmpty) {
        yield [];
        return;
      }

      List<List<dynamic>> chunks = [];
      for (var i = 0; i < savedIds.length; i += 10) {
        chunks.add(savedIds.sublist(i, i + 10 > savedIds.length ? savedIds.length : i + 10));
      }

      try {
        List<QuerySnapshot> snapshots = await Future.wait(
          chunks.map((chunk) => FirebaseFirestore.instance
              .collection('group_memories')
              .where(FieldPath.documentId, whereIn: chunk)
              .get()),
        );

        List<AlbumMemory> all = [];
        for (var snap in snapshots) {
          all.addAll(snap.docs.map((doc) => AlbumMemory.fromGroupFirestore(doc.data() as Map<String, dynamic>)));
        }
        all.sort((a, b) => b.date.compareTo(a.date));
        yield all;
      } catch (e) {
        debugPrint('Fallo al traer recuerdos grupales: $e');
        yield <AlbumMemory>[];
      }
    });
  }
}