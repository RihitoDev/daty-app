import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImageUploadService {
  static const String _apiKey = '9677a20efb9ed88209fe3e3d233ac361'; 

  static Future<XFile?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    return image;
  }

  static Future<String?> uploadImage(XFile image) async {
    if (_apiKey == '9677a20efb9ed88209fe3e3d233ac361') {
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
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}