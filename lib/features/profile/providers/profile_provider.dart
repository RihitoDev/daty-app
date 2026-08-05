import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/achievement_definition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/services/image_upload_service.dart';
import 'dart:async';
import '../../auth/utils/username_rules.dart';

class UsernameChangeStatus {
  final bool enabled;
  final DateTime? nextChangeAt;

  const UsernameChangeStatus({
    required this.enabled,
    this.nextChangeAt,
  });
}

class ProfileProvider extends ChangeNotifier {
  final AuthProvider _authProvider;

  bool _isLoading = true;
  String _userName = '';
  String _initials = 'AE';
  String _statusMessage = '';
  int _exp = 0;
  int _level = 1;
  double _progress = 0.0;
  int _nextExp = 100;
  int _coupleDates = 0;
  int _soloDates = 0;
  int _groupOutings = 0;
  int _daysTogether = 0;
  int _totalPhotosCount = 0;
  bool _isLinked = false;
  List<String> _equippedPins = [];

  String? _photoUrl;
  Uint8List? _selectedImageBytes;
  bool _isUploadingPhoto = false;

  static const int _expPerLevel = 100;

  bool get isLoading => _isLoading;
  String get userName => _userName;
  String get initials => _initials;
  String get statusMessage => _statusMessage;
  int get exp => _exp;
  int get level => _level;
  double get progress => _progress;
  int get nextExp => _nextExp;
  int get coupleDates => _coupleDates;
  int get soloDates => _soloDates;
  int get groupOutings => _groupOutings;
  int get daysTogether => _daysTogether;
  int get totalPhotosCount => _totalPhotosCount;
  bool get isLinked => _isLinked;
  List<String> get equippedPins => _equippedPins;
  String? get photoUrl => _photoUrl;
  Uint8List? get selectedImageBytes => _selectedImageBytes;
  bool get isUploadingPhoto => _isUploadingPhoto;

  String get rankTitle {
    if (_level <= 3) return 'Explorador Novato';
    if (_level <= 7) return 'Aventurero Constante';
    if (_level <= 12) return 'Gran Mapeador';
    if (_level <= 20) return 'Coleccionista de Historias';
    return 'Leyenda Inolvidable';
  }

  ProfileProvider(this._authProvider) {
    _authProvider.addListener(_onAuthDataChanged);
    _onAuthDataChanged();
  }

  void _onAuthDataChanged() {
    if (_authProvider.userData == null || _authProvider.user == null) return;

    final userData = _authProvider.userData!;
    final myUid = _authProvider.user!.uid;
    final String? partnerId = userData['partnerId'];

    _userName =
        userData['username'] ?? _authProvider.user?.displayName ?? 'Aventurero';
    _statusMessage = userData['statusMessage'] ?? '';
    _isLinked = partnerId != null;

    if (_userName.isNotEmpty) {
      List<String> parts = _userName.split(' ');
      if (parts.length > 1) {
        _initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        _initials =
            _userName.substring(0, _userName.length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    _exp = userData['exp'] ?? 0;
    _soloDates = userData['soloDatesCompleted'] ?? 0;
    _groupOutings = userData['groupOutingsCompleted'] ?? 0;
    _equippedPins = List<String>.from(userData['equippedPins'] ?? []);
    _photoUrl = userData['photoUrl'];

    _calculateLevel();
    _fetchTotalPhotos(myUid);

    if (_isLinked && partnerId != null) {
      _listenToCoupleDoc(myUid, partnerId);
    } else {
      _coupleDocSub?.cancel();
      _coupleDocSub = null;
      _coupleDates = 0;
      _daysTogether = 0;
    }

    _isLoading = false;
    notifyListeners();
  }

  void _calculateLevel() {
    _level = (_exp ~/ _expPerLevel) + 1;
    _progress = (_exp % _expPerLevel) / _expPerLevel;
    _nextExp = (_level) * _expPerLevel;
  }

  StreamSubscription<DocumentSnapshot>? _userDocSub;
  StreamSubscription<DocumentSnapshot>? _coupleDocSub;

  void startListeningToUserDoc() {
    final myUid = _authProvider.user?.uid;
    if (myUid == null) return;

    _userDocSub?.cancel();
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
      final newUserName = data?['username'] as String?;
      final newPartnerId = data?['partnerId'] as String?;
      final newStatusMessage = data?['statusMessage'] as String? ?? '';

      if (newExp != _exp ||
          newSoloDates != _soloDates ||
          newGroupOutings != _groupOutings) {
        _exp = newExp;
        _soloDates = newSoloDates;
        _groupOutings = newGroupOutings;
        _calculateLevel();
      }

      _equippedPins = newPins;
      _photoUrl = newPhotoUrl;
      _statusMessage = newStatusMessage;
      _isLinked = newPartnerId != null;

      if (newUserName != null && newUserName.trim().isNotEmpty) {
        _userName = newUserName.trim();
        _updateInitials();
      }

      if (_isLinked && newPartnerId != null) {
        _listenToCoupleDoc(myUid, newPartnerId);
      } else {
        _coupleDocSub?.cancel();
        _coupleDocSub = null;
        _coupleDates = 0;
        _daysTogether = 0;
      }

      _isLoading = false;
      notifyListeners();
    });
  }

  void _listenToCoupleDoc(String myUid, String partnerId) {
    _coupleDocSub?.cancel();
    String coupleDocId = myUid.compareTo(partnerId) < 0
        ? '${myUid}_$partnerId'
        : '${partnerId}_$myUid';

    _coupleDocSub = FirebaseFirestore.instance
        .collection('couples_progress')
        .doc(coupleDocId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        final path = List<int>.from(data['adventurePath'] ?? []);
        _coupleDates = path.length;

        final fechaVinculacion =
            (data['fechaVinculacion'] as Timestamp?)?.toDate();
        if (fechaVinculacion != null) {
          _daysTogether = DateTime.now().difference(fechaVinculacion).inDays;
          if (_daysTogether < 0) _daysTogether = 0;
        } else {
          _daysTogether = 0;
        }
        notifyListeners();
      }
    });
  }

  Future<void> _fetchTotalPhotos(String myUid) async {
    try {
      final querySnap = await FirebaseFirestore.instance
          .collection('memories')
          .where('userId', isEqualTo: myUid)
          .get();

      int count = 0;
      for (final doc in querySnap.docs) {
        final photos = List<String>.from(
            doc.data()['user1_photos'] ?? doc.data()['photos'] ?? []);
        count += photos.length;
      }
      _totalPhotosCount = count;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateStatusMessage(String message) async {
    final user = _authProvider.user;
    if (user == null) return;
    final trimmed = message.trim();
    if (trimmed.length > 60) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'statusMessage': trimmed,
    });
    _statusMessage = trimmed;
    notifyListeners();
  }

  void _updateInitials() {
    if (_userName.isEmpty) return;
    final parts = _userName.split(' ');
    _initials = parts.length > 1
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : _userName.substring(0, _userName.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<String?> updateUserName(String value) async {
    final user = _authProvider.user;
    if (user == null) return 'no-user';
    final newName = UsernameRules.clean(value);
    if (!UsernameRules.isValid(newName)) return 'invalid-name';
    if (newName == _userName) return null;

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('changeUsernameDuringEvent');
      await callable.call<void>({'username': newName});
      _userName = newName;
      _updateInitials();
      notifyListeners();
      return null;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'already-exists') return 'username-taken';
      if (error.code == 'failed-precondition') return 'cooldown-active';
      return 'server-error';
    } catch (_) {
      return 'unknown-error';
    }
  }

  Future<UsernameChangeStatus> getUsernameChangeStatus() async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getUsernameChangeStatus');
      final response = await callable.call<Map<String, dynamic>>();
      final data = response.data;
      final nextChangeAtMillis = data['nextChangeAtMillis'] as int?;
      return UsernameChangeStatus(
        enabled: data['enabled'] == true,
        nextChangeAt: nextChangeAtMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(nextChangeAtMillis),
      );
    } catch (_) {
      return const UsernameChangeStatus(
        enabled: false,
      );
    }
  }

  void stopListeningToUserDoc() {
    _userDocSub?.cancel();
    _userDocSub = null;
    _coupleDocSub?.cancel();
    _coupleDocSub = null;
  }

  int getCurrentValue(AchievementDefinition ach) {
    switch (ach.id) {
      case 'gen_welcome':
        return 1;
      case 'gen_link':
        return _isLinked ? 1 : 0;
      case 'gen_pin_equip':
        return _equippedPins.isNotEmpty ? 1 : 0;
      case 'gen_photo_5':
      case 'gen_photo_20':
        return _totalPhotosCount;
      case 'gen_level5':
      case 'gen_level10':
      case 'gen_level15':
        return _level;
      case 'solo_first':
      case 'solo_5':
      case 'solo_15':
      case 'solo_30':
        return _soloDates;
      case 'couple_first':
      case 'couple_10':
      case 'couple_25':
      case 'couple_50':
        return _coupleDates;
      case 'couple_contract':
        return _coupleDates >= 1 ? 1 : 0;
      case 'group_first':
      case 'group_5':
      case 'group_10':
      case 'group_20':
        return _groupOutings;
      default:
        return 0;
    }
  }

  Future<void> togglePin(String pinId, bool isEquipped) async {
    final myUid = _authProvider.user!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(myUid);

    final previousPins = List<String>.from(_equippedPins);

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

    try {
      if (isEquipped) {
        await userRef.update({
          'equippedPins': FieldValue.arrayRemove([pinId])
        });
      } else {
        await userRef.update({
          'equippedPins': FieldValue.arrayUnion([pinId])
        });
      }
    } catch (e) {
      debugPrint('Fallo al actualizar pin: $e');
      _equippedPins = previousPins;
      notifyListeners();
    }
  }

  Future<void> pickAndUploadImage(BuildContext context) async {
    final XFile? image =
        await ImageUploadService.pickAndCropProfileImage(context);
    if (image == null) return;

    _selectedImageBytes = await image.readAsBytes();
    _isUploadingPhoto = true;
    notifyListeners();

    final String? imageUrl = await ImageUploadService.uploadImage(
      image,
      folder: 'profiles',
    );

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
    _coupleDocSub?.cancel();
    super.dispose();
  }
}
