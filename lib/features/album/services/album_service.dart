import 'dart:async';
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
            .toList());
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
            .toList());
  }

  // SOLUCIÓN: Reestructurado con un StreamController para evitar el bloqueo del "await for"
  static Stream<List<AlbumMemory>> groupMemoriesStream(String myUid) {
    late StreamController<List<AlbumMemory>> controller;
    List<StreamSubscription> subscriptions = [];
    
    controller = StreamController<List<AlbumMemory>>(
      onListen: () async {
        final groupsSnapshot = await FirebaseFirestore.instance
            .collection('groups')
            .where('members', arrayContains: myUid)
            .get();

        if (groupsSnapshot.docs.isEmpty) {
          controller.add([]);
          return;
        }
        
        Map<String, List<AlbumMemory>> groupMemoriesMap = {};
        
        for (var groupDoc in groupsSnapshot.docs) {
          var sub = FirebaseFirestore.instance
              .collection('groups')
              .doc(groupDoc.id)
              .collection('memories')
              .orderBy('timestamp', descending: true)
              .limit(20)
              .snapshots()
              .listen((memSnapshot) {
                groupMemoriesMap[groupDoc.id] = memSnapshot.docs
                    .map((memDoc) => AlbumMemory.fromGroupFirestore(memDoc.data()))
                    .toList();
                
                List<AlbumMemory> allGroupMemories = [];
                for (var list in groupMemoriesMap.values) {
                  allGroupMemories.addAll(list);
                }
                allGroupMemories.sort((a, b) => b.date.compareTo(a.date));
                controller.add(allGroupMemories);
              });
              
          subscriptions.add(sub);
        }
      },
      onCancel: () {
        for (var sub in subscriptions) {
          sub.cancel();
        }
      }
    );
    
    return controller.stream;
  }

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