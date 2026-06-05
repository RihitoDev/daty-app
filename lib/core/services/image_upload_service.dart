import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImageUploadService {
  
  // Tomamos la llave del archivo .env, sin esto no podemos subir nada a ImgBB
  static String get _apiKey => dotenv.env['IMGBB_API_KEY'] ?? '';

  static Future<XFile?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Abrimos la galería y le bajamos la calidad al 70% para que no pese tanto al subirla
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    return image;
  }

  static Future<String?> uploadImage(XFile image) async {
    // Si falta la llave en el .env, frenamos aquí para no hacer peticiones al aire
    if (_apiKey.isEmpty) {
      debugPrint('ERROR: La API Key de ImgBB no está configurada en el archivo .env');
      return null;
    }

    try {
      final uri = Uri.parse('https://api.imgbb.com/1/upload?key=$_apiKey');
      
      List<int> imageBytes;
      // La web y los celulares leen los archivos de distinta forma, por eso separamos la lógica
      if (kIsWeb) {
        imageBytes = await image.readAsBytes();
      } else {
        File file = File(image.path);
        imageBytes = await file.readAsBytes();
      }

      // Convertimos la imagen a texto (base64) porque así la pide la API de ImgBB
      String base64Image = base64Encode(imageBytes);

      final request = http.MultipartRequest('POST', uri)
        ..fields['image'] = base64Image;

      final streamResponse = await request.send();
      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // Si todo sale bien, regresamos el enlace público de la foto
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