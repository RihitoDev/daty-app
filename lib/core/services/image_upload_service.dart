import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
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

  static Future<XFile?> pickAndCropProfileImage(
    BuildContext context,
  ) async {
    final picker = ImagePicker();
    final selected = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (selected == null || !context.mounted) return null;

    final colorScheme = Theme.of(context).colorScheme;
    final cropped = await ImageCropper().cropImage(
      sourcePath: selected.path,
      maxWidth: 1024,
      maxHeight: 1024,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Mueve y amplía tu foto',
          toolbarColor: const Color(0xFF171024),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: colorScheme.primary,
          backgroundColor: const Color(0xFF0E0917),
          dimmedLayerColor: Colors.black.withValues(alpha: .72),
          cropFrameColor: Colors.white,
          cropGridColor: Colors.white.withValues(alpha: .35),
          cropStyle: CropStyle.circle,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
          showCropGrid: false,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          title: 'Mueve y amplía tu foto',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          doneButtonTitle: 'Listo',
          cancelButtonTitle: 'Cancelar',
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 520, height: 520),
        ),
      ],
    );

    return cropped == null ? null : XFile(cropped.path);
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
