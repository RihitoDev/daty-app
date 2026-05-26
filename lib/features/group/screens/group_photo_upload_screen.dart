import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/image_upload_service.dart';
import 'group_memory_board_screen.dart';

class GroupPhotoUploadScreen extends StatefulWidget {
  final String groupCode;
  final Map<String, dynamic> adventureData;
  final List<String> members;

  const GroupPhotoUploadScreen({super.key, required this.groupCode, required this.adventureData, required this.members});

  @override
  State<GroupPhotoUploadScreen> createState() => _GroupPhotoUploadScreenState();
}

class _GroupPhotoUploadScreenState extends State<GroupPhotoUploadScreen> {
  XFile? _selectedPhoto;
  bool _isUploading = false;

  Future<void> _pickPhoto() async {
    final XFile? image = await ImageUploadService.pickImage();
    if (image != null) {
      setState(() { _selectedPhoto = image; });
    }
  }

  Future<void> _continue() async {
    setState(() => _isUploading = true);

    try {
      final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
      String? uploadedUrl;

      if (_selectedPhoto != null) {
        uploadedUrl = await ImageUploadService.uploadImage(_selectedPhoto!);
      }

      if (uploadedUrl != null) {
        String memoryDocId = '${widget.groupCode}_${widget.adventureData['number']}';
        await FirebaseFirestore.instance.collection('group_memories').doc(memoryDocId).update({
          'photos.$myUid': uploadedUrl,
        });
      }

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GroupMemoryBoardScreen(
          groupCode: widget.groupCode, 
          adventureData: widget.adventureData, 
          members: widget.members,
        )));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir la foto'), backgroundColor: Colors.redAccent));
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Recuerdo Grupal', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('¿Tienes una foto de la aventura?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Es opcional, pero un recuerdo siempre es valioso', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: 180, height: 180,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(25), border: Border.all(color: const Color(0xFF8E24AA), width: 2)),
                child: _selectedPhoto != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(23), child: Image.file(File(_selectedPhoto!.path), fit: BoxFit.cover))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Color(0xFF8E24AA), size: 50), SizedBox(height: 10), Text('Subir foto', style: TextStyle(color: Colors.white54, fontSize: 16))]),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _continue,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), disabledBackgroundColor: Colors.grey),
                icon: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.arrow_forward, color: Colors.white),
                label: const Text('Continuar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}