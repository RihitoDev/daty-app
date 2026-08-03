import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../auth/providers/auth_provider.dart';

class CoupleProvider with ChangeNotifier {
  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _coupleData;
  String _partnerName = 'tu pareja';
  bool _isLoading = true;
  StreamSubscription? _coupleSub;
  StreamSubscription? _partnerSub;
  String? _currentPartnerId;
  Timer? _retryTimer;

  CoupleProvider(this._authProvider) {
    _authProvider.addListener(_onAuthUpdate);
    _onAuthUpdate();
  }

  bool get hasPartner => _authProvider.userData?['partnerId'] != null;
  String get myUid => _authProvider.user!.uid;
  String? get partnerId => _currentPartnerId;
  String get partnerName => _partnerName;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get coupleData => _coupleData;

  String? get coupleDocId {
    if (_currentPartnerId == null) return null;
    return myUid.compareTo(_currentPartnerId!) < 0
        ? '${myUid}_$_currentPartnerId'
        : '${_currentPartnerId}_$myUid';
  }

  bool get isUser1 {
    if (_coupleData != null) {
      final u1 = _coupleData?['user1Id'] ?? _coupleData?['user1'];
      if (u1 != null) return u1 == myUid;
    }
    if (_currentPartnerId != null) {
      return myUid.compareTo(_currentPartnerId!) < 0;
    }
    return false;
  }

  bool get iSigned {
    if (_coupleData == null || _currentPartnerId == null) return false;
    return isUser1
        ? (_coupleData?['contractSignedUser1'] ?? false)
        : (_coupleData?['contractSignedUser2'] ?? false);
  }

  bool get partnerSigned {
    if (_coupleData == null || _currentPartnerId == null) return false;
    return isUser1
        ? (_coupleData?['contractSignedUser2'] ?? false)
        : (_coupleData?['contractSignedUser1'] ?? false);
  }

  void _onAuthUpdate() {
    final newPartnerId = _authProvider.userData?['partnerId'] as String?;
    if (newPartnerId != _currentPartnerId) {
      _currentPartnerId = newPartnerId;
      _cancelSubscriptions();
      if (_currentPartnerId != null) {
        _setupListeners(myUid, _currentPartnerId!);
      } else {
        _isLoading = false;
        _coupleData = null;
        _partnerName = 'tu pareja';
        notifyListeners();
      }
    }
  }

  void _cancelSubscriptions() {
    _coupleSub?.cancel();
    _partnerSub?.cancel();
    _coupleSub = null;
    _partnerSub = null;
    _retryTimer?.cancel();
  }

  void _setupListeners(String myUid, String partnerId) {
    _isLoading = true;
    notifyListeners();

    String coupleDocId = myUid.compareTo(partnerId) < 0
        ? '${myUid}_$partnerId'
        : '${partnerId}_$myUid';

    _coupleSub?.cancel();
    _coupleSub = _firestore
        .collection('couples_progress')
        .doc(coupleDocId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _coupleData = snapshot.data()!;
        _isLoading = false;
        _retryTimer?.cancel();
        notifyListeners();
      } else {
        _ensureCoupleDocExists(myUid, partnerId, coupleDocId);
      }
    }, onError: (e) {
      debugPrint('Error listening to couple doc $coupleDocId: $e');
      _ensureCoupleDocExists(myUid, partnerId, coupleDocId);
    });

    _partnerSub?.cancel();
    _partnerSub =
        _firestore.collection('users').doc(partnerId).snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          _partnerName = snapshot.data()?['username'] ?? 'tu pareja';
        }
        notifyListeners();
      },
    );
  }

  Future<void> _ensureCoupleDocExists(
      String myUid, String partnerId, String coupleDocId) async {
    try {
      if (_currentPartnerId != partnerId) return;
      final user1 = myUid.compareTo(partnerId) < 0 ? myUid : partnerId;
      final user2 = myUid.compareTo(partnerId) < 0 ? partnerId : myUid;
      final docRef = _firestore.collection('couples_progress').doc(coupleDocId);

      // Usar set con merge: true directamente sin hacer get() previo,
      // para evitar que las reglas de lectura fallen si el documento aún no existe en Firestore.
      await docRef.set({
        'user1': user1,
        'user2': user2,
        'user1Id': user1,
        'user2Id': user2,
        'fechaVinculacion': FieldValue.serverTimestamp(),
        'contractSignedUser1': false,
        'contractSignedUser2': false,
        'xpPareja': 0,
        'nivelPareja': 1,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error ensuring couple doc exists: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthUpdate);
    _cancelSubscriptions();
    super.dispose();
  }
}
