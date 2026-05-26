import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImageUploadService {
  // ⚠️ PEGA AQUÍ TU API KEY DE IMGBB (Es gratis)
  static const String _apiKey = '9677a20efb9ed88209fe3e3d233ac361'; 

  /// Selecciona una imagen de la galería
  static Future<XFile?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    return image;
  }

  /// Sube la imagen a ImgBB y devuelve la URL pública
  static Future<String?> uploadImage(XFile image) async {
    if (_apiKey == 'TU_API_KEY_AQUI') {
      print('⚠️ ERROR: No has configurado tu API Key de ImgBB en image_upload_service.dart');
      return null;
    }

    try {
      final uri = Uri.parse('https://api.imgbb.com/1/upload?key=$_apiKey');
      
      List<int> imageBytes;
      if (kIsWeb) {
        imageBytes = await image.readAsBytes();
      } else {
        File file = File(image.path);
        imageBytes = await file.readAsBytes();
      }

      String base64Image = base64Encode(imageBytes);

      final request = http.MultipartRequest('POST', uri)
        ..fields['image'] = base64Image;

      final streamResponse = await request.send();
      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['data']['url']; // ¡URL pública devuelta!
      } else {
        print('Error al subir imagen: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Excepción subiendo imagen: $e');
      return null;
    }
  }
}