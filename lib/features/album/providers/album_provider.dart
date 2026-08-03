import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/album_memory.dart';
import '../services/album_service.dart';

class PausedCoupleGroup {
  final String coupleDocId;
  final String partnerName;
  final DateTime? preservationWindowEnd;
  final DateTime? unlinkedAt;
  final List<AlbumMemory> memories;

  const PausedCoupleGroup({
    required this.coupleDocId,
    required this.partnerName,
    required this.preservationWindowEnd,
    required this.unlinkedAt,
    required this.memories,
  });
}

class AlbumProvider with ChangeNotifier {
  final AuthProvider _authProvider;

  String? _partnerId;
  String _partnerName = 'Pareja';
  bool _isUser1 = false;
  String _myName = 'Yo';

  String? get partnerId => _partnerId;
  String get partnerName => _partnerName;
  bool get isUser1 => _isUser1;
  String get myName => _myName;

  AlbumProvider(this._authProvider) {
    _authProvider.addListener(_onAuthUpdate);
    _loadPartnerData();
  }

  void _onAuthUpdate() {
    _loadPartnerData();
  }

  Future<void> _loadPartnerData() async {
    final user = _authProvider.user;
    if (user == null) return;

    final myUid = user.uid;
    _myName = _authProvider.userData?['username'] ?? 'Yo';
    _partnerId = _authProvider.userData?['partnerId'];

    if (_partnerId != null) {
      _isUser1 = myUid.compareTo(_partnerId!) < 0;

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_partnerId)
            .get();
        if (doc.exists) {
          _partnerName = doc.data()?['username'] ?? 'Pareja';
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Stream<List<AlbumMemory>> get soloStream {
    if (_authProvider.user == null) return Stream.value([]);
    return AlbumService.soloMemoriesStream(_authProvider.user!.uid)
        .map((list) => list.where((m) => !m.isPersonal).toList());
  }

  Stream<List<AlbumMemory>> get coupleStream {
    if (_authProvider.user == null) {
      return Stream.value([]);
    }
    final myUid = _authProvider.user!.uid;

    if (_partnerId != null) {
      String coupleDocId = _isUser1
          ? '${myUid}_$_partnerId'
          : '${_partnerId}_$myUid';
      return AlbumService.coupleMemoriesStream(
              coupleDocId,
              _isUser1 ? _myName : _partnerName,
              _isUser1 ? _partnerName : _myName)
          .map((list) => list.where((m) => !m.isPersonal).toList());
    }

    return Stream.value([]);
  }

  Stream<List<PausedCoupleGroup>> get pausedCoupleGroupsStream {
    return _buildPausedCoupleGroupsStream();
  }

  Stream<List<PausedCoupleGroup>> _buildPausedCoupleGroupsStream() {
    if (_authProvider.user == null) return Stream.value([]);
    final myUid = _authProvider.user!.uid;

    final memoriesStream = FirebaseFirestore.instance
        .collection('memories')
        .snapshots();

    final couplesProgressStream = FirebaseFirestore.instance
        .collection('couples_progress')
        .snapshots();

    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .snapshots();

    return Rx.combineLatest3<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        List<PausedCoupleGroup>>(
      memoriesStream,
      couplesProgressStream,
      usersStream,
      (memSnap, couplesSnap, usersSnap) {
        final now = DateTime.now();

        final usersMap = <String, Map<String, dynamic>>{};
        for (final doc in usersSnap.docs) {
          usersMap[doc.id] = doc.data();
        }

        final myUserData = usersMap[myUid];
        final currentPartnerId = myUserData?['partnerId'] as String?;
        final isUser1 = currentPartnerId != null
            ? myUid.compareTo(currentPartnerId) < 0
            : false;

        final activeCoupleId = currentPartnerId != null
            ? (isUser1 ? '${myUid}_$currentPartnerId' : '${currentPartnerId}_$myUid')
            : null;

        final couplesMap = <String, Map<String, dynamic>>{};
        for (final doc in couplesSnap.docs) {
          couplesMap[doc.id] = doc.data();
        }

        final groupMap = <String, List<AlbumMemory>>{};
        final preservationMap = <String, DateTime?>{};

        for (final doc in memSnap.docs) {
          final data = doc.data();
          if (data['isPersonal'] == true) continue;
          final coupleDocId = data['coupleDocId'] as String?;
          if (coupleDocId == null || coupleDocId.isEmpty) continue;

          final coupleData = couplesMap[coupleDocId];
          final isFullySignedActive = coupleData != null &&
              coupleData['contractSignedUser1'] == true &&
              coupleData['contractSignedUser2'] == true &&
              coupleData['unlinkingState'] == null;

          if (isFullySignedActive && coupleDocId == activeCoupleId) continue;

          final u1 = data['user1Id'] ?? data['user1'];
          final u2 = data['user2Id'] ?? data['user2'];
          final userId = data['userId'];

          final isMember = myUid == u1 ||
              myUid == u2 ||
              myUid == userId ||
              coupleDocId.contains(myUid);
          if (!isMember) continue;

          final memoryDate = AlbumMemory.parseDate(data['timestamp'] ?? data['date'] ?? data['createdAt']);
          DateTime preservationEnd = memoryDate.add(const Duration(days: 7));

          if (coupleData != null) {
            if (coupleData['preservationWindowEnd'] != null) {
              preservationEnd = AlbumMemory.parseDate(coupleData['preservationWindowEnd']);
            } else if (coupleData['unlinkedAt'] != null) {
              final unlinkedAt = AlbumMemory.parseDate(coupleData['unlinkedAt']);
              preservationEnd = unlinkedAt.add(const Duration(days: 7));
            }
          } else if (data['preservationWindowEnd'] != null) {
            preservationEnd = AlbumMemory.parseDate(data['preservationWindowEnd']);
          }

          if (now.isAfter(preservationEnd)) {
            continue;
          }

          preservationMap[coupleDocId] = preservationEnd;

          final memory = AlbumMemory.fromCoupleFirestore(
            data,
            'Yo',
            'Pareja',
            id: doc.id,
          ).copyWith(preservationWindowEnd: preservationEnd);

          groupMap.putIfAbsent(coupleDocId, () => []).add(memory);
        }

        final groups = <PausedCoupleGroup>[];
        for (final entry in groupMap.entries) {
          final docId = entry.key;
          final memories = entry.value;
          memories.sort((a, b) => b.date.compareTo(a.date));

          String partnerName = 'Pareja anterior';
          if (docId.contains('_')) {
            final parts = docId.split('_');
            final pId = parts[0] == myUid ? parts[1] : parts[0];
            final pUserData = usersMap[pId];
            if (pUserData != null && pUserData['username'] != null) {
              partnerName = pUserData['username'].toString();
            }
          }

          groups.add(PausedCoupleGroup(
            coupleDocId: docId,
            partnerName: partnerName,
            preservationWindowEnd: preservationMap[docId],
            unlinkedAt: memories.first.date,
            memories: memories,
          ));
        }

        groups.sort((a, b) {
          final tA = a.unlinkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tB = b.unlinkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tB.compareTo(tA);
        });

        return groups;
      },
    ).asBroadcastStream();
  }

  Stream<List<AlbumMemory>> get pausedCoupleStream {
    return pausedCoupleGroupsStream.map((groups) {
      final merged = groups.expand((g) => g.memories).toList();
      merged.sort((a, b) => b.date.compareTo(a.date));
      return merged;
    });
  }

  Stream<List<AlbumMemory>> get groupStream {
    if (_authProvider.user == null) return Stream.value([]);
    return AlbumService.groupMemoriesStream(_authProvider.user!.uid)
        .map((list) => list.where((m) => !m.isPersonal).toList());
  }

  Stream<List<AlbumMemory>> get personalStream {
    if (_authProvider.user == null) return Stream.value([]);
    final myUid = _authProvider.user!.uid;

    final soloPersonal = FirebaseFirestore.instance
        .collection('solo_memories')
        .where('userId', isEqualTo: myUid)
        .where('isPersonal', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AlbumMemory.fromSoloFirestore(d.data(), id: d.id))
            .toList());

    final couplePersonal = FirebaseFirestore.instance
        .collection('memories')
        .where('isPersonal', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .where((d) {
              final data = d.data();
              return data['userId'] == myUid ||
                  data['user1Id'] == myUid ||
                  data['user2Id'] == myUid ||
                  data['unlinkedBy'] == myUid;
            })
            .map((d) => AlbumMemory.fromCoupleFirestore(
                d.data(), _myName, _partnerName,
                id: d.id))
            .toList());

    final groupPersonal = FirebaseFirestore.instance
        .collection('group_memories')
        .where('isPersonal', isEqualTo: true)
        .where('userId', isEqualTo: myUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AlbumMemory.fromGroupFirestore(d.data(), id: d.id))
            .toList());

    return Rx.combineLatest3<List<AlbumMemory>, List<AlbumMemory>,
        List<AlbumMemory>, List<AlbumMemory>>(
      soloPersonal,
      couplePersonal,
      groupPersonal,
      (s, c, g) {
        final all = [...s, ...c, ...g];
        all.sort((a, b) => b.date.compareTo(a.date));
        return all;
      },
    );
  }

  Stream<List<AlbumMemory>> get allStream {
    return Rx.combineLatest3<List<AlbumMemory>, List<AlbumMemory>,
        List<AlbumMemory>, List<AlbumMemory>>(
      soloStream,
      coupleStream,
      groupStream,
      (soloMemories, coupleMemories, groupMemories) {
        final allMemories = [
          ...soloMemories,
          ...coupleMemories,
          ...groupMemories
        ];
        allMemories.sort((a, b) => b.date.compareTo(a.date));
        return allMemories;
      },
    );
  }
}