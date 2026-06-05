import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/album_memory.dart';
import '../services/album_service.dart';

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
    // Escuchamos los cambios en la autenticación para recargar la data si el usuario se desloguea o cambia
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
      // Ordenamos los UIDs alfabéticamente para saber quién es user1 y asegurar que el ID del documento de pareja siempre se genere igual
      _isUser1 = myUid.compareTo(_partnerId!) < 0;
      
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(_partnerId).get();
        if (doc.exists) {
          _partnerName = doc.data()?['username'] ?? 'Pareja';
        }
      } catch (_) {
        // Si falla la lectura del nombre, nos quedamos con el valor por defecto silenciosamente
      }
    }
    notifyListeners();
  }

  Stream<List<AlbumMemory>> get soloStream {
    if (_authProvider.user == null) return Stream.value([]);
    return AlbumService.soloMemoriesStream(_authProvider.user!.uid);
  }

  Stream<List<AlbumMemory>> get coupleStream {
    if (_partnerId == null || _authProvider.user == null) return Stream.value([]);
    
    // Armamos el ID compuesto basándonos en la bandera _isUser1 que calculamos arriba
    String coupleDocId = _isUser1 ? '${_authProvider.user!.uid}_$_partnerId' : '${_partnerId}_${_authProvider.user!.uid}';
    return AlbumService.coupleMemoriesStream(coupleDocId, _isUser1 ? _myName : _partnerName, _isUser1 ? _partnerName : _myName);
  }

  Stream<List<AlbumMemory>> get groupStream {
    if (_authProvider.user == null) return Stream.value([]);
    return AlbumService.groupMemoriesStream(_authProvider.user!.uid);
  }

  Stream<List<AlbumMemory>> get allStream {
    // Usamos combineLatest3 de RxDart para fusionar los tres streams. 
    // Cada vez que Firebase empuje un cambio a cualquiera de los tres, esta función se vuelve a disparar y reordena todo.
    return Rx.combineLatest3<List<AlbumMemory>, List<AlbumMemory>, List<AlbumMemory>, List<AlbumMemory>>(
      soloStream,
      coupleStream,
      groupStream,
      (soloMemories, coupleMemories, groupMemories) {
        final allMemories = [...soloMemories, ...coupleMemories, ...groupMemories];
        
        // Ordenamos toda la mezcla por fecha para la vista de "Todos"
        allMemories.sort((a, b) => b.date.compareTo(a.date));
        return allMemories;
      },
    );
  }
}