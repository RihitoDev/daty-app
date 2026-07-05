import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/achievement_definition.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/image_upload_service.dart';
import 'dart:async';

class ProfileProvider extends ChangeNotifier {
  final AuthProvider _authProvider;

  bool _isLoading = true;
  String _userName = '';
  String _initials = 'AE';
  int _exp = 0;
  int _level = 1;
  double _progress = 0.0;
  int _nextExp = 100;
  int _coupleDates = 0;
  int _soloDates = 0;
  int _groupOutings = 0;
  bool _isLinked = false;
  List<String> _equippedPins = [];
  
  String? _photoUrl;
  Uint8List? _selectedImageBytes;
  bool _isUploadingPhoto = false;

  // Cuánta XP se necesita para pasar de nivel. Cambiar aquí si se ajusta la curva.
  static const int _expPerLevel = 100;

  bool get isLoading => _isLoading;
  String get userName => _userName;
  String get initials => _initials;
  int get exp => _exp;
  int get level => _level;
  double get progress => _progress;
  int get nextExp => _nextExp;
  int get coupleDates => _coupleDates;
  int get soloDates => _soloDates;
  int get groupOutings => _groupOutings;
  bool get isLinked => _isLinked;
  List<String> get equippedPins => _equippedPins;
  String? get photoUrl => _photoUrl;
  Uint8List? get selectedImageBytes => _selectedImageBytes;
  bool get isUploadingPhoto => _isUploadingPhoto;

  ProfileProvider(this._authProvider) {
    _authProvider.addListener(_onAuthDataChanged);
    _onAuthDataChanged(); 
  }

  void _onAuthDataChanged() {
    if (_authProvider.userData == null || _authProvider.user == null) return;

    final userData = _authProvider.userData!;
    final myUid = _authProvider.user!.uid;
    final String? partnerId = userData['partnerId'];

    _userName = userData['username'] ?? _authProvider.user?.displayName ?? 'Aventurero';
    _isLinked = partnerId != null;

    if (_userName.isNotEmpty) {
      List<String> parts = _userName.split(' ');
      if (parts.length > 1) {
        _initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        _initials = _userName.substring(0, _userName.length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    _exp = userData['exp'] ?? 0;
    _soloDates = userData['soloDatesCompleted'] ?? 0;
    _groupOutings = userData['groupOutingsCompleted'] ?? 0;
    _equippedPins = List<String>.from(userData['equippedPins'] ?? []);
    _photoUrl = userData['photoUrl'];

    _calculateLevel();

    if (_isLinked && partnerId != null) {
      _fetchCoupleData(myUid, partnerId);
    } else {
      _coupleDates = 0;
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Cálculo centralizado del nivel. Todo pasa por aquí. ───
  // Si en el futuro la curva cambia (ej. niveles exponenciales), 
  // solo se toca este método.
  void _calculateLevel() {
    _level = (_exp ~/ _expPerLevel) + 1;
    _progress = (_exp % _expPerLevel) / _expPerLevel;
    _nextExp = (_level) * _expPerLevel;
  }


  StreamSubscription<DocumentSnapshot>? _userDocSub;

  void startListeningToUserDoc() {
    final myUid = _authProvider.user?.uid;
    if (myUid == null) return;

    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data();

      final newExp = data?['exp'] ?? 0;
      final newSoloDates = data?['soloDatesCompleted'] ?? 0;
      final newGroupOutings = data?['groupOutingsCompleted'] ?? 0;
      final newPins = List<String>.from(data?['equippedPins'] ?? []);
      final newPhotoUrl = data?['photoUrl'];

      // Solo notificamos si algo cambió para evitar rebuilds innecesarios
      if (newExp != _exp || newSoloDates != _soloDates || newGroupOutings != _groupOutings) {
        _exp = newExp;
        _soloDates = newSoloDates;
        _groupOutings = newGroupOutings;
        _calculateLevel();
      }

      _equippedPins = newPins;
      _photoUrl = newPhotoUrl;

      _isLoading = false;
      notifyListeners();
    });
  }

  void stopListeningToUserDoc() {
    _userDocSub?.cancel();
    _userDocSub = null;
  }

  Future<void> _fetchCoupleData(String myUid, String partnerId) async {
    try {
      String coupleDocId = myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';
      
      final coupleDoc = await FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId).get();
      if (coupleDoc.exists) {
        _coupleDates = List<int>.from(coupleDoc.data()!['adventurePath'] ?? []).length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching couple data for profile: $e');
    }
  }

  int getCurrentValue(AchievementDefinition ach) {
    switch (ach.id) {
      case 'gen_welcome': return 1;
      case 'gen_link': return _isLinked ? 1 : 0;
      case 'gen_level5': return _level;
      case 'gen_level10': return _level;
      case 'solo_first': case 'solo_5': case 'solo_15': return _soloDates;
      case 'couple_first': case 'couple_10': case 'couple_25': case 'couple_50': return _coupleDates;
      case 'couple_contract': return _coupleDates >= 1 ? 1 : 0;
      case 'group_first': case 'group_5': case 'group_10': return _groupOutings;
      default: return 0;
    }
  }

  // ─── Toggle pin con rollback si falla la escritura ───
  Future<void> togglePin(String pinId, bool isEquipped) async {
    final myUid = _authProvider.user!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(myUid);

    // Optimistic update: cambiamos el UI inmediatamente
    final previousPins = List<String>.from(_equippedPins);

    if (isEquipped) {
      _equippedPins.remove(pinId);
    } else {
      if (_equippedPins.length < 3) {
        _equippedPins.add(pinId);
      } else {
        return; // No hay espacio, no hacemos nada
      }
    }
    notifyListeners();

    try {
      if (isEquipped) {
        await userRef.update({'equippedPins': FieldValue.arrayRemove([pinId])});
      } else {
        await userRef.update({'equippedPins': FieldValue.arrayUnion([pinId])});
      }
    } catch (e) {
      debugPrint('Fallo al actualizar pin: $e');
      // Rollback: restauramos el estado anterior si la escritura falló
      _equippedPins = previousPins;
      notifyListeners();
    }
  }

  Future<void> pickAndUploadImage() async {
    final XFile? image = await ImageUploadService.pickImage();
    if (image == null) return;

    _selectedImageBytes = await image.readAsBytes();
    _isUploadingPhoto = true;
    notifyListeners();

    final String? imageUrl = await ImageUploadService.uploadImage(image);

    if (imageUrl != null) {
      final myUid = _authProvider.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(myUid).update({
        'photoUrl': imageUrl,
      });
    } 
    
    _selectedImageBytes = null;
    _isUploadingPhoto = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthDataChanged);
    _userDocSub?.cancel();
    super.dispose();
  }
}