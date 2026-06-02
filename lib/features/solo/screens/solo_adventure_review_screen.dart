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
  String? _formError;
  
  final List<Uint8List?> _selectedImageBytes = [null, null];
  final List<String?> _uploadedPhotoUrls = [null, null];
  final List<bool> _isUploading = [false, false];

  bool get _isValid {
    if (_rating == 0) return false;
    List<String> words = _reviewController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 3) return false;
    if (_uploadedPhotoUrls.every((url) => url == null)) return false;
    if (_isUploading.any((uploading) => uploading)) return false;
    return true;
  }

  void _validateForm() {
    List<String> words = _reviewController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    setState(() {
      if (_rating == 0) {
        _formError = 'Debes seleccionar al menos 1 estrella.';
      } else if (words.length < 3) {
        _formError = 'Describe tu experiencia (minimo 3 palabras).';
      } else if (_uploadedPhotoUrls.every((url) => url == null)) {
        _formError = 'Debes subir al menos 1 foto de la aventura.';
      } else if (_isUploading.any((uploading) => uploading)) {
        _formError = 'Espera a que las fotos terminen de subir.';
      } else {
        _formError = null;
      }
    });
  }

  Future<void> _pickPhoto(int index) async {
    final XFile? image = await ImageUploadService.pickImage();
    if (image != null) {
      final bytes = await image.readAsBytes();
      
      setState(() {
        _selectedImageBytes[index] = bytes;
        _isUploading[index] = true;
        _formError = null;
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
    _validateForm();
    if (_formError != null) return;

    bool hasConnection = await NetworkService.isConnected;
    if (!hasConnection) {
      setState(() => _formError = 'Sin conexion a internet. Verifica tu red.');
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
        
        transaction.update(FirebaseFirestore.instance.collection('users').doc(myUid), {
          'exp': FieldValue.increment(expEarned),
          'soloDatesCompleted': FieldValue.increment(1)
        });

        Map<String, dynamic> updateData = {'activeAdventureNumber': FieldValue.delete()};
        if (widget.availableAdventuresIds.isNotEmpty) {
          final random = Random();
          int nextAdventureId = widget.availableAdventuresIds[random.nextInt(widget.availableAdventuresIds.length)];
          updateData['adventurePath'] = FieldValue.arrayUnion([nextAdventureId]);
        }
        transaction.update(FirebaseFirestore.instance.collection('solo_progress').doc(myUid), updateData);
      });

      if (mounted) Navigator.pop(context); 
    } catch (e) {
      if(mounted) {
        setState(() {
          _formError = 'Error al guardar. Intenta de nuevo.';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Como estuvo la aventura?', style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 60, color: Colors.blue.shade300),
            const SizedBox(height: 10),
            Text(widget.adventureData['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1976D2)), textAlign: TextAlign.center),
            const SizedBox(height: 25),
            
            if (_formError != null) _buildErrorBanner(_formError!),
            if (_formError != null) const SizedBox(height: 15),

            const Text('Califica tu experiencia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: List.generate(5, (index) => IconButton(
                icon: Icon(index < _rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 40), 
                onPressed: () => setState(() { _rating = index + 1; _formError = null; })
              ))
            ),
            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Text('Describe en 3 o mas palabras:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            TextField(
              controller: _reviewController, 
              maxLines: 3, 
              decoration: InputDecoration(
                hintText: 'Ej: Divertida, relajante, inolvidable...', 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), 
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2))
              ), 
              onChanged: (_) => setState(() => _formError = null)
            ), 
            const SizedBox(height: 30),
            const Align(alignment: Alignment.centerLeft, child: Row(children: [Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF1976D2)), SizedBox(width: 6), Text('Sube hasta 2 fotos (1 obligatoria):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))])),
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
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: _isValid && !_isSubmitting ? _submitReview : null,
                style: ElevatedButton.styleFrom(backgroundColor: _isValid ? const Color(0xFF1976D2) : Colors.grey.shade300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                icon: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, color: Colors.white),
                label: Text(_isSubmitting ? 'Guardando...' : 'Guardar y Ganar EXP', style: TextStyle(color: _isValid ? Colors.white : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5))),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
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
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_selectedImageBytes[index] != null)
                ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.memory(_selectedImageBytes[index]!, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
              else
                const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: Color(0xFF1976D2), size: 40), SizedBox(height: 5), Text('Foto', style: TextStyle(color: Colors.grey))]),
              
              if (_isUploading[index])
                Container(decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15)), alignment: Alignment.center, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 5), Text('Subiendo...', style: TextStyle(color: Colors.white, fontSize: 10))])),
                
              if (_uploadedPhotoUrls[index] != null && !_isUploading[index])
                Positioned(top: 5, right: 5, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 12)))
            ],
          ),
        ),
      ),
    );
  }
}