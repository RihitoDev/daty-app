import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/services/network_service.dart';
import '../../shared/widgets/full_screen_image_viewer.dart';

class SoloAdventureReviewScreen extends StatefulWidget {
  final Map<String, dynamic> adventureData; 
  final List<int> availableAdventuresIds; 

  const SoloAdventureReviewScreen({super.key, required this.adventureData, required this.availableAdventuresIds});

  @override
  State<SoloAdventureReviewScreen> createState() => _SoloAdventureReviewScreenState();
}

class _SoloAdventureReviewScreenState extends State<SoloAdventureReviewScreen> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;
  
  final List<Uint8List?> _selectedImageBytes = [null, null];
  final List<String?> _uploadedPhotoUrls = [null, null];
  final List<bool> _isUploading = [false, false];

  bool get _isValid {
    if (_rating == 0) return false;
    List<String> words = _reviewController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.length >= 3;
  }

  Future<void> _pickPhoto(int index) async {
    final XFile? image = await ImageUploadService.pickImage();
    if (image != null) {
      final bytes = await image.readAsBytes();
      
      setState(() {
        _selectedImageBytes[index] = bytes;
        _isUploading[index] = true;
      });

      final url = await ImageUploadService.uploadImage(image);
      
      if (mounted) {
        setState(() {
          _uploadedPhotoUrls[index] = url;
          _isUploading[index] = false;
        });
      }
    }
  }

  Future<void> _submitReview() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La calificación y la descripción (mínimo 3 palabras) son obligatorias.')));
      return;
    }

    if (_isUploading.any((uploading) => uploading)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Espera a que las fotos terminen de subir.')));
      return;
    }

    bool hasConnection = await NetworkService.isConnected;
    if (!hasConnection) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sin conexión a internet. Verifica tu red e intenta de nuevo.'), backgroundColor: Colors.redAccent));
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final myUid = authProvider.user!.uid;
      int adventureId = widget.adventureData['number'];
      String memoryDocId = '${myUid}_$adventureId'; 
      int expEarned = widget.adventureData['xpBase'] ?? 50; 

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        Map<String, dynamic> memoryData = {
          'userId': myUid,
          'adventure_title': widget.adventureData['title'],
          'id_adventure': adventureId.toString(),
          'timestamp': FieldValue.serverTimestamp(),
          'rating': _rating,
          'review': _reviewController.text.trim(),
          'photos': _uploadedPhotoUrls.whereType<String>().toList(),
        };
        transaction.set(FirebaseFirestore.instance.collection('solo_memories').doc(memoryDocId), memoryData);
        transaction.update(FirebaseFirestore.instance.collection('users').doc(myUid), {'exp': FieldValue.increment(expEarned)});

        Map<String, dynamic> updateData = {'activeAdventureNumber': FieldValue.delete()};
        if (widget.availableAdventuresIds.isNotEmpty) {
          final random = Random();
          int nextAdventureId = widget.availableAdventuresIds[random.nextInt(widget.availableAdventuresIds.length)];
          updateData['adventurePath'] = FieldValue.arrayUnion([nextAdventureId]);
        }
        transaction.update(FirebaseFirestore.instance.collection('solo_progress').doc(myUid), updateData);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text('¡Aventura completada! +$expEarned EXP'), duration: const Duration(seconds: 2)));
        Navigator.pop(context); 
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.redAccent));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('¿Cómo estuvo la aventura?', style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
        centerTitle: true, 
        backgroundColor: Colors.white, 
        elevation: 0, 
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(widget.adventureData['emoji'] ?? '📍', style: const TextStyle(fontSize: 60)),
            const SizedBox(height: 10),
            Text(widget.adventureData['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1976D2)), textAlign: TextAlign.center,),
            const SizedBox(height: 25),
            const Text('Califica tu experiencia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: List.generate(5, (index) => IconButton(
                icon: Icon(index < _rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 40), 
                onPressed: () => setState(() => _rating = index + 1)
              ))
            ),
            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Text('Describe en 3 o más palabras:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            TextField(
              controller: _reviewController, 
              maxLines: 3, 
              decoration: InputDecoration(
                hintText: 'Ej: Divertida, relajante, inolvidable...', 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), 
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2))
              ), 
              onChanged: (_) => setState(() {})
            ), 
            const SizedBox(height: 30),
            const Align(alignment: Alignment.centerLeft, child: Text('📸 Sube hasta 2 fotos:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildPhotoPicker(0),
                const SizedBox(width: 15),
                _buildPhotoPicker(1),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, 
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isValid && !_isSubmitting ? _submitReview : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isValid ? const Color(0xFF1976D2) : Colors.grey.shade300, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                ),
                icon: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle, color: Colors.white),
                label: Text(_isSubmitting ? 'Guardando...' : 'Guardar y Ganar EXP', style: TextStyle(color: _isValid ? Colors.white : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker(int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_uploadedPhotoUrls[index] != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: _uploadedPhotoUrls[index]!)));
          } else {
            _pickPhoto(index);
          }
        },
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade200, 
            borderRadius: BorderRadius.circular(15), 
            border: Border.all(color: Colors.grey.shade300)
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_selectedImageBytes[index] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(15), 
                  child: Image.memory(_selectedImageBytes[index]!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                )
              else
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 40), 
                    SizedBox(height: 5), 
                    Text('Foto', style: TextStyle(color: Colors.grey))
                  ]
                ),
              
              if (_isUploading[index])
                Container(
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15)),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 5),
                      Text('Subiendo...', style: TextStyle(color: Colors.white, fontSize: 10))
                    ],
                  ),
                ),
                
              if (_uploadedPhotoUrls[index] != null && !_isUploading[index])
                Positioned(
                  top: 5, right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 12),
                  )
                )
            ],
          ),
        ),
      ),
    );
  }
}