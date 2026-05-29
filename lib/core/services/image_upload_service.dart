import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImageUploadService {
  
  // LEEMOS LA VARIABLE DE ENTORNO
  static String get _apiKey => dotenv.env['IMGBB_API_KEY'] ?? '';

  static Future<XFile?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    return image;
  }

  static Future<String?> uploadImage(XFile image) async {
    // Pequeña validación por si acaso no cargó el .env
    if (_apiKey.isEmpty) {
      debugPrint('ERROR: La API Key de ImgBB no está configurada en el archivo .env');
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
        return responseData['data']['url']; 
      } else {
        debugPrint('Error ImgBB: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Excepción subiendo a ImgBB: $e');
      return null;
    }
  }
}