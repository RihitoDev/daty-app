import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  bool _isInitializing = true;

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;

      if (user != null) {
        _listenToUserData(user.uid);
      } else {
        _userData = null;
        _userDocSubscription?.cancel();
        _userDocSubscription = null;
      }

      _isInitializing = false;
      notifyListeners();
    });
  }

  void _listenToUserData(String uid) {
    _userDocSubscription?.cancel();

    _userDocSubscription =
        _firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _userData = snapshot.data();
      } else {
        _userData = null;
      }

      notifyListeners();
    });
  }

  String _normalizeUsername(String username) {
    return username
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('/', '-');
  }

  Future<bool> isUsernameTaken(String username) async {
    final normalizedUsername = _normalizeUsername(username);

    if (normalizedUsername.isEmpty) {
      return false;
    }

    final usernameSnapshot =
        await _firestore.collection('usernames').doc(normalizedUsername).get();

    return usernameSnapshot.exists;
  }

  Future<void> _reserveUsername({
    required User user,
    required String username,
  }) async {
    final rawUsername = username.trim();
    final normalizedUsername = _normalizeUsername(rawUsername);

    if (normalizedUsername.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-username',
      );
    }

    final usernameDoc =
        _firestore.collection('usernames').doc(normalizedUsername);

    await _firestore.runTransaction((transaction) async {
      final usernameSnapshot = await transaction.get(usernameDoc);

      if (usernameSnapshot.exists) {
        final data = usernameSnapshot.data();

        if (data == null || data['uid'] != user.uid) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'username-taken',
          );
        }

        return;
      }

      transaction.set(usernameDoc, {
        'uid': user.uid,
        'username': rawUsername,
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _releaseUsernameReservation(User user) async {
    final displayName = user.displayName?.trim() ?? '';

    if (displayName.isEmpty) return;

    final normalizedUsername = _normalizeUsername(displayName);

    final usernameDoc =
        _firestore.collection('usernames').doc(normalizedUsername);

    await _firestore.runTransaction((transaction) async {
      final usernameSnapshot = await transaction.get(usernameDoc);

      if (!usernameSnapshot.exists) return;

      final data = usernameSnapshot.data();

      if (data != null && data['uid'] == user.uid) {
        transaction.delete(usernameDoc);
      }
    });
  }

  Future<void> _createUserDocument(
    User user, {
    String? usernameOverride,
  }) async {
    final rawUsername = usernameOverride?.trim().isNotEmpty == true
        ? usernameOverride!.trim()
        : (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Aventurero');

    final normalizedUsername = _normalizeUsername(rawUsername);

    if (normalizedUsername.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-username',
      );
    }

    final userDoc = _firestore.collection('users').doc(user.uid);

    final usernameDoc =
        _firestore.collection('usernames').doc(normalizedUsername);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userDoc);
      final usernameSnapshot = await transaction.get(usernameDoc);

      if (userSnapshot.exists) {
        return;
      }

      if (!usernameSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'username-reservation-not-found',
        );
      }

      final usernameData = usernameSnapshot.data();

      if (usernameData == null || usernameData['uid'] != user.uid) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'username-taken',
        );
      }

      transaction.set(userDoc, {
        'username': rawUsername,
        'usernameNormalized': normalizedUsername,
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'partnerId': null,
        'exp': 0,
        'soloDatesCompleted': 0,
        'groupOutingsCompleted': 0,
        'equippedPins': [],
        'rachaDias': 0,
        'fechaRegistro': FieldValue.serverTimestamp(),
        'dismissedGroupMemories': [],
      });
    });
  }

  Future<String?> signIn(
    String email,
    String password,
  ) async {
    _setLoading(true);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user?.reload();
      _user = _auth.currentUser;

      return null;
    } on FirebaseAuthException catch (e) {
      return e.code;
    } catch (e) {
      debugPrint('Error desconocido al iniciar sesión: $e');
      return 'unknown-error';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> register(
    String email,
    String password,
    String username,
  ) async {
    _setLoading(true);

    User? createdUser;

    try {
      final cleanUsername = username.trim();

      if (cleanUsername.isEmpty) {
        return 'invalid-username';
      }

      final usernameTaken = await isUsernameTaken(cleanUsername);

      if (usernameTaken) {
        return 'username-taken';
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        return 'no-user';
      }

      await createdUser.updateDisplayName(cleanUsername);
      await createdUser.reload();

      createdUser = _auth.currentUser;

      if (createdUser == null) {
        return 'no-user';
      }

      // Reserva el username antes de enviar el correo.
      await _reserveUsername(
        user: createdUser,
        username: cleanUsername,
      );

      // Solo después de reservar correctamente, enviamos la verificación.
      await createdUser.sendEmailVerification();

      _user = createdUser;

      return null;
    } on FirebaseAuthException catch (e) {
      return e.code;
    } on FirebaseException catch (e) {
      debugPrint('Error de Firestore durante el registro: ${e.code}');

      // Si ya se creó la cuenta, pero no se pudo reservar el username,
      // eliminamos la cuenta incompleta.
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (deleteError) {
          debugPrint(
            'No se pudo eliminar la cuenta incompleta: $deleteError',
          );
        }
      }

      if (e.code == 'username-taken') {
        return 'username-taken';
      }

      if (e.code == 'permission-denied') {
        return 'firestore-error';
      }

      return 'firestore-error';
    } catch (e) {
      debugPrint('Error desconocido al registrar: $e');

      if (createdUser != null) {
        try {
          await _releaseUsernameReservation(createdUser);
          await createdUser.delete();
        } catch (deleteError) {
          debugPrint(
            'No se pudo limpiar la cuenta incompleta: $deleteError',
          );
        }
      }

      return 'unknown-error';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> createProfileAfterVerification(
    String username,
  ) async {
    _setLoading(true);

    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        return 'no-user';
      }

      await currentUser.reload();

      final updatedUser = _auth.currentUser;

      if (updatedUser == null) {
        return 'no-user';
      }

      if (!updatedUser.emailVerified) {
        return 'not-verified';
      }

      final finalUsername = username.trim().isNotEmpty
          ? username.trim()
          : updatedUser.displayName?.trim() ?? '';

      if (finalUsername.isEmpty) {
        return 'invalid-username';
      }

      await _createUserDocument(
        updatedUser,
        usernameOverride: finalUsername,
      );

      _user = updatedUser;
      notifyListeners();

      return null;
    } on FirebaseException catch (e) {
      debugPrint('Error al crear el perfil: ${e.code}');

      if (e.code == 'username-taken') {
        return 'username-taken';
      }

      return 'firestore-error';
    } catch (e) {
      debugPrint('Error desconocido al crear el perfil: $e');
      return 'firestore-error';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> refreshCurrentUser() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return false;
    }

    try {
      await currentUser.reload();
      _user = _auth.currentUser;
      notifyListeners();

      return _user?.emailVerified ?? false;
    } catch (e) {
      debugPrint('No se pudo actualizar el usuario: $e');
      return false;
    }
  }

  Future<String?> resendVerificationEmail() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return 'no-user';
    }

    try {
      await currentUser.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.code;
    } catch (e) {
      debugPrint('Error al reenviar la verificación: $e');
      return 'unknown-error';
    }
  }

  Future<String?> signInWithGoogle() async {
    _setLoading(true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return 'cancelled';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }

      return null;
    } catch (e) {
      debugPrint('Error al iniciar sesión con Google: $e');
      return 'error';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
      );

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'not-found';
      }

      return e.code;
    } catch (e) {
      debugPrint('Error al recuperar la contraseña: $e');
      return 'error';
    }
  }

  Future<String?> deletePendingAccount() async {
    _setLoading(true);

    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        return 'no-user';
      }

      await currentUser.reload();

      final updatedUser = _auth.currentUser;

      if (updatedUser == null) {
        return 'no-user';
      }

      if (updatedUser.emailVerified) {
        return 'already-verified';
      }

      _userDocSubscription?.cancel();
      _userDocSubscription = null;

      await _releaseUsernameReservation(updatedUser);
      await updatedUser.delete();

      _user = null;
      _userData = null;
      notifyListeners();

      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error al eliminar cuenta pendiente: ${e.code}');
      return e.code;
    } on FirebaseException catch (e) {
      debugPrint('Error al liberar el username: ${e.code}');
      return 'firestore-error';
    } catch (e) {
      debugPrint('Error desconocido al eliminar cuenta pendiente: $e');
      return 'unknown-error';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);

    try {
      _userDocSubscription?.cancel();
      _userDocSubscription = null;

      await _auth.signOut();

      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('No se pudo cerrar Google Sign-In: $e');
      }

      _user = null;
      _userData = null;
    } catch (e) {
      debugPrint('Fallo al cerrar sesión: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
