import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/image_upload_service.dart';

class AdventureReviewScreen extends StatefulWidget {
  final Map<String, dynamic> adventureData; 
  final List<int> availableAdventuresIds; 

  const AdventureReviewScreen({super.key, required this.adventureData, required this.availableAdventuresIds});

  @override
  State<AdventureReviewScreen> createState() => _AdventureReviewScreenState();
}

class _AdventureReviewScreenState extends State<AdventureReviewScreen> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;
  final List<XFile?> _selectedPhotos = [null, null];
  final List<String?> _uploadedPhotoUrls = [null, null];

  bool get _isValid {
    if (_rating == 0) return false;
    List<String> words = _reviewController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.length >= 3;
  }

  Future<void> _pickPhoto(int index) async {
    final XFile? image = await ImageUploadService.pickImage();
    if (image != null) {
      setState(() { _selectedPhotos[index] = image; });
    }
  }

  Future<void> _submitReview() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La calificación y la descripción (mínimo 3 palabras) son obligatorias.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final myUid = authProvider.user!.uid;
      final partnerId = authProvider.userData!['partnerId'];
      
      String coupleDocId = myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';
      int adventureId = widget.adventureData['number'];
      String memoryDocId = '${coupleDocId}_$adventureId'; 
      
      bool isUser1 = myUid.compareTo(partnerId) < 0;
      String userPrefix = isUser1 ? 'user1' : 'user2';
      String myReviewField = isUser1 ? 'reviewCompletedUser1' : 'reviewCompletedUser2';
      String partnerReviewField = isUser1 ? 'reviewCompletedUser2' : 'reviewCompletedUser1';

      bool partnerJustReviewed = false;

      for (int i = 0; i < 2; i++) {
        if (_selectedPhotos[i] != null) {
          final url = await ImageUploadService.uploadImage(_selectedPhotos[i]!);
          if (url != null) _uploadedPhotoUrls[i] = url;
        }
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final coupleSnap = await transaction.get(FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId));
        final coupleData = coupleSnap.data() as Map<String, dynamic>;
        bool partnerReviewed = coupleData[partnerReviewField] ?? false;

        Map<String, dynamic> memoryData = {
          'adventure_title': widget.adventureData['title'],
          'id_adventure': adventureId.toString(),
          'coupleDocId': coupleDocId,
          'timestamp': FieldValue.serverTimestamp(),
          '${userPrefix}_rating': _rating,
          '${userPrefix}_review': _reviewController.text.trim(),
          '${userPrefix}_photos': _uploadedPhotoUrls.whereType<String>().toList(),
        };
        transaction.set(FirebaseFirestore.instance.collection('memories').doc(memoryDocId), memoryData, SetOptions(merge: true));
        transaction.update(FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId), {myReviewField: true});

        if (partnerReviewed) {
          partnerJustReviewed = true;
          int expEarned = widget.adventureData['xpBase'] ?? 50; 
          
          transaction.update(FirebaseFirestore.instance.collection('users').doc(myUid), {'exp': FieldValue.increment(expEarned)});
          transaction.update(FirebaseFirestore.instance.collection('users').doc(partnerId), {'exp': FieldValue.increment(expEarned)});

          Map<String, dynamic> updateData = {
            'activeAdventureNumber': FieldValue.delete(), 
            'reviewCompletedUser1': FieldValue.delete(), 
            'reviewCompletedUser2': FieldValue.delete(),
          };
          if (widget.availableAdventuresIds.isNotEmpty) {
            final random = Random();
            int nextAdventureId = widget.availableAdventuresIds[random.nextInt(widget.availableAdventuresIds.length)];
            updateData['adventurePath'] = FieldValue.arrayUnion([nextAdventureId]);
          }
          transaction.update(FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId), updateData);
        }
      });

      if (mounted) {
        if (partnerJustReviewed) {
          int expEarned = widget.adventureData['xpBase'] ?? 50;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text('¡Ambos calificaron! +$expEarned EXP'), duration: const Duration(seconds: 2)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text('¡Calificación guardada! Esperando a tu pareja...'), duration: Duration(seconds: 3)));
        }
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
        title: const Text('¿Cómo estuvo la cita?', style: TextStyle(color: Color(0xFFC2185B), fontWeight: FontWeight.bold)),
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
            Text(widget.adventureData['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFC2185B)), textAlign: TextAlign.center,),
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
                hintText: 'Ej: Divertida, romántica, inolvidable...', 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), 
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFC2185B), width: 2))
              ), 
              onChanged: (_) => setState(() {})
            ), 
            const SizedBox(height: 30),
            const Align(alignment: Alignment.centerLeft, child: Text('📸 Sube hasta 2 fotos:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildPhotoPicker(0, const Color(0xFFC2185B)),
                const SizedBox(width: 15),
                _buildPhotoPicker(1, const Color(0xFFC2185B)),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, 
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isValid && !_isSubmitting ? _submitReview : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isValid ? const Color(0xFFC2185B) : Colors.grey.shade300, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                ),
                icon: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle, color: Colors.white),
                label: Text(_isSubmitting ? 'Guardando...' : 'Enviar Calificación', style: TextStyle(color: _isValid ? Colors.white : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker(int index, Color themeColor) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _pickPhoto(index),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade200, 
            borderRadius: BorderRadius.circular(15), 
            border: Border.all(color: Colors.grey.shade300)
          ),
          child: _selectedPhotos[index] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15), 
                child: Image.file(File(_selectedPhotos[index]!.path), fit: BoxFit.cover)
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: [
                  Icon(Icons.add_a_photo_outlined, color: themeColor.withOpacity(0.5), size: 40), 
                  const SizedBox(height: 5), 
                  Text('Foto ${index + 1}', style: const TextStyle(color: Colors.grey))
                ]
              ),
        ),
      ),
    );
  }
}