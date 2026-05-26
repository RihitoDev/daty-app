import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/album_memory.dart';

class AlbumService {
  static Future<List<AlbumMemory>> fetchAllMemories({
    required String myUid,
    required String myName,
    required String? partnerId,
    required String partnerName,
    required bool isUser1,
  }) async {
    List<AlbumMemory> tempMemories = [];

    try {
      final soloSnap = await FirebaseFirestore.instance.collection('solo_memories').where('userId', isEqualTo: myUid).get();
      for (var doc in soloSnap.docs) {
        try {
          final data = doc.data();
          tempMemories.add(AlbumMemory(
            type: 'Solo', title: data['adventure_title'] ?? 'Aventura', emoji: '🧘‍♂️',
            date: parseDate(data['timestamp']),
            reviews: [if (data['review'] != null && data['review'].toString().isNotEmpty) data['review']],
            photoUrls: List<String>.from(data['photos'] ?? []),
          ));
        } catch (e) {
          debugPrint('Error parsing solo memory ${doc.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetching solo memories: $e');
    }

    if (partnerId != null) {
      try {
        String coupleDocId = isUser1 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';
        final coupleSnap = await FirebaseFirestore.instance.collection('memories').where('coupleDocId', isEqualTo: coupleDocId).get();
        String user1Name = isUser1 ? myName : partnerName;
        String user2Name = isUser1 ? partnerName : myName;
        
        for (var doc in coupleSnap.docs) {
          try {
            final data = doc.data();
            List<String> reviews = [];
            List<String> photos = [];
            if (data['user1_review'] != null && data['user1_review'].toString().isNotEmpty) reviews.add('$user1Name: ${data['user1_review']}');
            if (data['user2_review'] != null && data['user2_review'].toString().isNotEmpty) reviews.add('$user2Name: ${data['user2_review']}');
            photos.addAll(List<String>.from(data['user1_photos'] ?? []));
            photos.addAll(List<String>.from(data['user2_photos'] ?? []));

            tempMemories.add(AlbumMemory(
              type: 'Pareja', title: data['adventure_title'] ?? 'Cita', emoji: '❤️',
              date: parseDate(data['timestamp']),
              reviews: reviews, photoUrls: photos,
            ));
          } catch (e) {
            debugPrint('Error parsing couple memory ${doc.id}: $e');
          }
        }
      } catch (e) {
        debugPrint('Error fetching couple memories: $e');
      }
    }

    try {
      final groupSnap = await FirebaseFirestore.instance.collection('group_memories').where('members', arrayContains: myUid).get();
      for (var doc in groupSnap.docs) {
        try {
          final data = doc.data();
          tempMemories.add(AlbumMemory(
            type: 'Grupo', title: data['adventure_title'] ?? 'Expedición', emoji: '👥',
            date: parseDate(data['timestamp']),
            reviews: [],
            photoUrls: List<String>.from((data['photos'] as Map?)?.values ?? []),
          ));
        } catch (e) {
          debugPrint('Error parsing group memory ${doc.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetching group memories: $e');
    }

    tempMemories.sort((a, b) {
      int dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      return b.title.compareTo(a.title);
    });

    return tempMemories;
  }

  static DateTime parseDate(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    return DateTime.now();
  }
}