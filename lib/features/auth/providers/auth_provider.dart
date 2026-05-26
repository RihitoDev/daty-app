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
  bool _isInitializing = true; // NUEVO: Para evitar el parpadeo al arrancar

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing; // NUEVO GETTER

  AuthProvider() {
    _auth.authStateChanges().listen((User? u) {
      _user = u;
      if (u != null) {
        _listenToUserData(u.uid);
      } else {
        _userData = null;
      }
      _isInitializing = false; // Firebase terminó de revisar la sesión
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

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      // Devolvemos false, pero podrías lanzar el error para mostrar mensajes específicos en la UI
      debugPrint('Error de login: ${e.code}');
      return false; 
    } catch (e) {
      _setLoading(false);
      return false;
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
          await _firestore.collection('users').doc(credential.user!.uid).set({
            "username": username.trim(),
            "email": email.trim(),
            "photoUrl": null,
            "partnerId": null,         
            "exp": 0,                  
            "soloDatesCompleted": 0,   
            "groupOutingsCompleted": 0,
            "equippedPins": [],        
            "rachaDias": 0,           
            "fechaRegistro": FieldValue.serverTimestamp(),
            // ELIMINADOS nivelJugador y xpTotal para evitar desincronización con profile_screen
          });
        } catch (firestoreError) {
          _setLoading(false);
          return 'Error al crear tu perfil en la base de datos. Inténtalo de nuevo.'; 
        }
      }
      
      _setLoading(false);
      return null; // Éxito
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      if (e.code == 'weak-password') return 'La contraseña es muy debil (mínimo 6 caracteres).';
      if (e.code == 'email-already-in-use') return 'El correo ya esta registrado.';
      return 'Error de autenticación. Verifica tus datos.';
    } catch (e) {
      _setLoading(false);
      return 'Ocurrio un error inesperado al guardar tu perfil.';
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return false; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
        
        if (!userDoc.exists) {
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            "username": userCredential.user!.displayName ?? "Aventurero", 
            "email": userCredential.user!.email ?? "",
            "photoUrl": userCredential.user!.photoURL,
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

      _setLoading(false);
      return true; 
    } catch (e) {
      _setLoading(false);
      return false;
    }
  }

  // NUEVO: Recuperar contraseña
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // Éxito
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