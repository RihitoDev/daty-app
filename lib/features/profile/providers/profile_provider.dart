import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/achievement_definition.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/image_upload_service.dart';

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
    // Escuchamos los cambios de AuthProvider (que ya escucha Firestore en tiempo real)
    _authProvider.addListener(_onAuthDataChanged);
    _onAuthDataChanged(); // Carga inicial
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

    // Extraer datos directos del cache de AuthProvider (0 lecturas extra en Firestore)
    _exp = userData['exp'] ?? 0;
    _soloDates = userData['soloDatesCompleted'] ?? 0;
    _groupOutings = userData['groupOutingsCompleted'] ?? 0;
    _equippedPins = List<String>.from(userData['equippedPins'] ?? []);
    _photoUrl = userData['photoUrl'];

    _calculateLevel();

    // Cargar fechas de pareja si está vinculado
    if (_isLinked && partnerId != null) {
      _fetchCoupleData(myUid, partnerId);
    } else {
      _coupleDates = 0;
    }

    _isLoading = false;
    notifyListeners();
  }

  void _calculateLevel() {
    _level = (_exp / 100).floor() + 1;
    _progress = (_exp % 100) / 100.0;
    _nextExp = ((_exp ~/ 100) + 1) * 100;
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

  void togglePin(String pinId, bool isEquipped) {
    if (isEquipped) {
      _equippedPins.remove(pinId);
    } else {
      if (_equippedPins.length < 3) {
        _equippedPins.add(pinId);
      } else {
        return;
      }
    }
    notifyListeners();

    final myUid = _authProvider.user!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(myUid);
    if (isEquipped) {
      userRef.update({'equippedPins': FieldValue.arrayRemove([pinId])});
    } else {
      userRef.update({'equippedPins': FieldValue.arrayUnion([pinId])});
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
    super.dispose();
  }
}