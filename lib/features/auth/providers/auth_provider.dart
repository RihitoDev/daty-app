import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // Escuchamos los cambios de sesión. Si entra alguien, nos enganchamos a su doc en Firestore.
    _auth.authStateChanges().listen((User? u) {
      _user = u;
      if (u != null) {
        _listenToUserData(u.uid);
      } else {
        _userData = null;
        _userDocSubscription?.cancel(); 
      }
      _isInitializing = false;
      notifyListeners();
    });
  }

  // Mantiene _userData sincronizado en tiempo real si el doc cambia en la base de datos
  void _listenToUserData(String uid) {
    _userDocSubscription?.cancel();
    _userDocSubscription = _firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _userData = snapshot.data();
        notifyListeners();
      }
    });
  }

  // Prepara el documento del usuario con los campos base si es su primera vez.
  // Usamos merge: true para evitar el race condition TOCTOU entre el get() y el set():
  // si un registro duplicado (o un Cloud Function) creara el doc entre ambos, no lo sobreescribiríamos.
  Future<void> _createUserDocument(User user, {String? usernameOverride}) async {
    final userDoc = _firestore.collection('users').doc(user.uid);

    await userDoc.set({
      "username": usernameOverride ?? user.displayName ?? "Aventurero",
      "email": user.email ?? "",
      "photoUrl": user.photoURL,
      "partnerId": null,
      "exp": 0,
      "soloDatesCompleted": 0,
      "groupOutingsCompleted": 0,
      "equippedPins": [],
      "rachaDias": 0,
      "fechaRegistro": FieldValue.serverTimestamp(),
      "dismissedGroupMemories": [],
    }, SetOptions(merge: true));
  }

  Future<String?> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      _setLoading(false);
      return null; 
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return e.code; 
    } catch (e) {
      _setLoading(false);
      return 'unknown-error';
    }
  }

  Future<String?> register(String email, String password, String username) async {
    _setLoading(true);
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password,
      );
      
      if (credential.user != null) {
        await credential.user!.updateDisplayName(username.trim());
        try {
          await _createUserDocument(credential.user!, usernameOverride: username.trim());
        } catch (firestoreError) {
          _setLoading(false);
          return 'firestore-error'; 
        }
      }
      
      _setLoading(false);
      return null; 
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return e.code; 
    } catch (e) {
      _setLoading(false);
      return 'unknown-error';
    }
  }

  Future<String?> signInWithGoogle() async {
    _setLoading(true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return 'cancelled'; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!);
      }

      _setLoading(false);
      return null; 
    } catch (e) {
      _setLoading(false);
      return 'error'; 
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return 'not-found';
      return 'error';
    } catch (e) {
      return 'error';
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      // Delegamos la limpieza de _user y _userData al listener authStateChanges(),
      // que es la única fuente de verdad para el estado de sesión. Esto evita el doble
      // notifyListeners() y el posible flicker de loading que generaba setearlos a mano.
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Fallo al cerrar sesión: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }
}