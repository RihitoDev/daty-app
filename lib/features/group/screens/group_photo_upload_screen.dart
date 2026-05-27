import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/services/network_service.dart';
import '../../shared/widgets/full_screen_image_viewer.dart';
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
  Uint8List? _selectedImageBytes;
  String? _uploadedPhotoUrl;
  bool _isUploading = false;

  Future<void> _pickPhoto() async {
    final XFile? image = await ImageUploadService.pickImage();
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() { 
        _selectedImageBytes = bytes;
        _isUploading = true;
      });

      final url = await ImageUploadService.uploadImage(image);
      if (mounted) {
        setState(() {
          _uploadedPhotoUrl = url;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _continue() async {
    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Espera a que la foto termine de subir.')));
      return;
    }

    bool hasConnection = await NetworkService.isConnected;
    if (!hasConnection) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sin conexión a internet.'), backgroundColor: Colors.redAccent));
      return;
    }

    try {
      final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;

      if (_uploadedPhotoUrl != null) {
        String memoryDocId = '${widget.groupCode}_${widget.adventureData['number']}';
        await FirebaseFirestore.instance.collection('group_memories').doc(memoryDocId).update({
          'photos.$myUid': _uploadedPhotoUrl,
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
              onTap: () {
                if (_uploadedPhotoUrl != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: _uploadedPhotoUrl!)));
                } else {
                  _pickPhoto();
                }
              },
              child: Container(
                width: 180, height: 180,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(25), border: Border.all(color: const Color(0xFF8E24AA), width: 2)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_selectedImageBytes != null)
                      ClipRRect(borderRadius: BorderRadius.circular(23), child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity))
                    else
                      const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Color(0xFF8E24AA), size: 50), SizedBox(height: 10), Text('Subir foto', style: TextStyle(color: Colors.white54, fontSize: 16))]),
                    
                    if (_isUploading)
                      Container(decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(23)), alignment: Alignment.center, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 5), Text('Subiendo...', style: TextStyle(color: Colors.white, fontSize: 10))])),

                    if (_uploadedPhotoUrl != null && !_isUploading)
                      Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 16)))
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: _continue,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), disabledBackgroundColor: Colors.grey),
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                label: const Text('Continuar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}