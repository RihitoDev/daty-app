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

  bool get iSigned {
    if (_coupleData == null || _currentPartnerId == null) return false;
    bool isUser1 = myUid.compareTo(_currentPartnerId!) < 0;
    return isUser1 ? (_coupleData?['contractSignedUser1'] ?? false) : (_coupleData?['contractSignedUser2'] ?? false);
  }

  bool get partnerSigned {
    if (_coupleData == null || _currentPartnerId == null) return false;
    bool isUser1 = myUid.compareTo(_currentPartnerId!) < 0;
    return isUser1 ? (_coupleData?['contractSignedUser2'] ?? false) : (_coupleData?['contractSignedUser1'] ?? false);
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

    String coupleDocId = myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';

    _coupleSub = _firestore.collection('couples_progress').doc(coupleDocId).snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          _coupleData = snapshot.data()!;
          _isLoading = false;
          _retryTimer?.cancel();
          notifyListeners();
        } else {
          _coupleData = null;
          _isLoading = false;
          notifyListeners();
          _fetchCoupleDataWithRetry(coupleDocId);
        }
      },
      onError: (e) {
        _isLoading = false;
        _coupleData = null;
        notifyListeners();
      }
    );

    _partnerSub = _firestore.collection('users').doc(partnerId).snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          _partnerName = snapshot.data()?['username'] ?? 'tu pareja';
        }
        notifyListeners();
      },
    );
  }

  void _fetchCoupleDataWithRetry(String docId) {
    if (_coupleData != null) return;
    _retryTimer?.cancel();

    int attempts = 0;
    const maxAttempts = 3;

    void attemptFetch() {
      if (_coupleData != null || _currentPartnerId == null || attempts >= maxAttempts) return;
      attempts++;
      _retryTimer = Timer(Duration(seconds: attempts * 2), () async {
        try {
          final doc = await _firestore.collection('couples_progress').doc(docId).get();
          if (doc.exists && _coupleData == null) {
            _coupleData = doc.data()!;
            notifyListeners();
          } else if (_coupleData == null) {
            attemptFetch();
          }
        } catch (e) {
          debugPrint('Retry fetch couple data attempt $attempts: $e');
          if (_coupleData == null && attempts < maxAttempts) {
            attemptFetch();
          }
        }
      });
    }

    attemptFetch();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthUpdate);
    _cancelSubscriptions();
    super.dispose();
  }
}