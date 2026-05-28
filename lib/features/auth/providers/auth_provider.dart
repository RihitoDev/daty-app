import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  bool _isInitializing = true;

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;

  AuthProvider() {
    _auth.authStateChanges().listen((User? u) {
      _user = u;
      if (u != null) {
        _listenToUserData(u.uid);
      } else {
        _userData = null;
      }
      _isInitializing = false;
      notifyListeners();
    });
  }

  void _listenToUserData(String uid) {
    _firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _userData = snapshot.data();
        notifyListeners();
      }
    });
  }

  // NUEVO: Método centralizado para crear el documento en Firestore
  Future<void> _createUserDocument(User user, {String? usernameOverride}) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    // Solo lo creamos si no existe (evita sobrescribir si el usuario ya existía)
    if (!docSnapshot.exists) {
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
      });
    }
  }

  Future<String?> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      _setLoading(false);
      return null; // Éxito
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return e.code; // Devolvemos el código de error para que la UI lo interprete
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
          // Usamos el método centralizado
          await _createUserDocument(credential.user!, usernameOverride: username.trim());
        } catch (firestoreError) {
          _setLoading(false);
          return 'Error al crear tu perfil en la base de datos. Inténtalo de nuevo.'; 
        }
      }
      
      _setLoading(false);
      return null; // Éxito
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      return e.code; // 'weak-password', 'email-already-in-use', etc.
    } catch (e) {
      _setLoading(false);
      return 'unknown-error';
    }
  }

  // CAMBIO: Ahora devuelve String? en vez de bool para diferenciar cancelación de error
  Future<String?> signInWithGoogle() async {
    _setLoading(true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return 'cancelled'; // El usuario cerró el popup
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Usamos el método centralizado
        await _createUserDocument(userCredential.user!);
      }

      _setLoading(false);
      return null; // Éxito
    } catch (e) {
      _setLoading(false);
      return 'error'; // Error real
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return 'No existe una cuenta con este correo.';
      return 'Error al enviar el correo de recuperación.';
    } catch (e) {
      return 'Ocurrió un error inesperado.';
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      _user = null;
      _userData = null;
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}