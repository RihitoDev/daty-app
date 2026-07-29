import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImageUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<XFile?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    return image;
  }

  /// Subir imagen a Firebase Storage y obtener su URL pública de descarga.
  /// [folder]: Carpeta destino ('memories', 'profiles', etc.)
  static Future<String?> uploadImage(
    XFile image, {
    String folder = 'memories',
  }) async {
    try {
      final user = _auth.currentUser;
      final uid = user?.uid ?? 'anonymous';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${image.name}';

      final ref = _storage.ref().child('$folder/$uid/$fileName');

      String contentType = 'image/jpeg';
      final lowerName = image.name.toLowerCase();
      if (lowerName.endsWith('.png')) {
        contentType = 'image/png';
      } else if (lowerName.endsWith('.webp')) {
        contentType = 'image/webp';
      } else if (lowerName.endsWith('.gif')) {
        contentType = 'image/gif';
      }

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        uploadTask = ref.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
      } else {
        final file = File(image.path);
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: contentType),
        );
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Imagen subida con éxito a Firebase Storage: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error subiendo imagen a Firebase Storage: $e');
      return null;
    }
  }
}