import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/album_memory.dart';
import '../services/album_service.dart';

class AlbumProvider with ChangeNotifier {
  final AuthProvider _authProvider;

  String? _partnerId;
  String _partnerName = 'Pareja';
  bool _isUser1 = false;
  String _myName = 'Yo';
  
  List<AlbumMemory> _allMemories = [];
  bool _isLoadingAll = false;
  
  List<AlbumMemory> get allMemories => _allMemories;
  bool get isLoadingAll => _isLoadingAll;
  String? get partnerId => _partnerId;
  String get partnerName => _partnerName;
  bool get isUser1 => _isUser1;
  String get myName => _myName;

  AlbumProvider(this._authProvider) {
    _loadPartnerData();
  }

  Future<void> _loadPartnerData() async {
    final myUid = _authProvider.user!.uid;
    _myName = _authProvider.userData?['username'] ?? 'Yo';
    _partnerId = _authProvider.userData?['partnerId'];

    if (_partnerId != null) {
      _isUser1 = myUid.compareTo(_partnerId!) < 0;
      final doc = await FirebaseFirestore.instance.collection('users').doc(_partnerId).get();
      if (doc.exists) {
        _partnerName = doc.data()?['username'] ?? 'Pareja';
      }
    }
    notifyListeners();
  }

  Future<void> fetchAllMemories() async {
    _isLoadingAll = true;
    notifyListeners();

    try {
      final myUid = _authProvider.user!.uid;
      _allMemories = await AlbumService.fetchAllMemories(
        myUid: myUid,
        myName: _myName,
        partnerId: _partnerId,
        partnerName: _partnerName,
        isUser1: _isUser1,
      );
    } catch (e) {
      debugPrint('Error en AlbumProvider fetchAllMemories: $e');
    }

    _isLoadingAll = false;
    notifyListeners();
  }

  Stream<List<AlbumMemory>> get soloStream {
    return AlbumService.soloMemoriesStream(_authProvider.user!.uid);
  }

  Stream<List<AlbumMemory>> get coupleStream {
    if (_partnerId == null) return Stream.value([]);
    String coupleDocId = _isUser1 ? '${_authProvider.user!.uid}_$_partnerId' : '$_partnerId}_${_authProvider.user!.uid}';
    return AlbumService.coupleMemoriesStream(coupleDocId, _isUser1 ? _myName : _partnerName, _isUser1 ? _partnerName : _myName);
  }

  Stream<List<AlbumMemory>> get groupStream {
    return AlbumService.groupMemoriesStream(_authProvider.user!.uid);
  }
}