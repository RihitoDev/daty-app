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
  Timer? _retryTimer; // Timer para el reintento

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
        _partnerName = 'tu pareja'; // Limpiar nombre de ex
        notifyListeners();
      }
    }
  }

  void _cancelSubscriptions() {
    _coupleSub?.cancel();
    _partnerSub?.cancel();
    _coupleSub = null;
    _partnerSub = null;
    _retryTimer?.cancel(); // Cancelar reintento si cambiamos de estado
  }

  void _setupListeners(String myUid, String partnerId) {
    _isLoading = true;
    notifyListeners();

    String coupleDocId = myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';
    debugPrint("🔥 [CoupleProvider] Escuchando documento couples_progress/$coupleDocId");

    _coupleSub = _firestore.collection('couples_progress').doc(coupleDocId).snapshots().listen(
      (snapshot) {
        debugPrint("🔥 [CoupleProvider] Snapshot recibido -> ¿Existe?: ${snapshot.exists}");
        if (snapshot.exists) {
          _coupleData = snapshot.data()!;
          _isLoading = false;
          _retryTimer?.cancel(); // Si llega el dato, cancelamos el reintento
          notifyListeners();
        } else {
          _coupleData = null;
          _isLoading = false;
          notifyListeners();
          
          // 🚨 SOLUCIÓN: Si el stream dice que no existe, programamos un reintento manual
          // Esto arregla el bug de caché de Firestore al re-vincular
          _fetchCoupleDataWithRetry(coupleDocId);
        }
      },
      onError: (e) {
        debugPrint("❌ [CoupleProvider] ERROR en stream: $e");
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

  // 🚨 Función mágica para desatascar la caché de Firestore
  void _fetchCoupleDataWithRetry(String docId) {
    // Si ya tenemos datos o ya estamos esperando, no hacer nada
    if (_coupleData != null || _retryTimer?.isActive == true) return;

    _retryTimer = Timer(const Duration(seconds: 2), () async {
      if (_coupleData == null && _currentPartnerId != null) {
        debugPrint("🔥 [CoupleProvider] Reintentando obtener documento manualmente...");
        try {
          final doc = await _firestore.collection('couples_progress').doc(docId).get();
          if (doc.exists && _coupleData == null) {
            debugPrint("🔥 [CoupleProvider] ¡Documento encontrado en reintento manual!");
            _coupleData = doc.data()!;
            notifyListeners();
          }
        } catch (e) {
          debugPrint("❌ [CoupleProvider] Error en reintento manual: $e");
        }
      }
    });
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthUpdate);
    _cancelSubscriptions();
    super.dispose();
  }
}