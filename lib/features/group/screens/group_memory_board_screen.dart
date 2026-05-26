import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/image_upload_service.dart';
import '../../home/screens/home_screen.dart';

class GroupMemoryBoardScreen extends StatelessWidget {
  final String groupCode;
  final Map<String, dynamic> adventureData;
  final List<String> members;

  const GroupMemoryBoardScreen({super.key, required this.groupCode, required this.adventureData, required this.members});

  Future<void> _saveToAlbum(BuildContext context) async {
    final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
    String memoryDocId = '${groupCode}_${adventureData['number']}';
    
    await FirebaseFirestore.instance.collection('users').doc(myUid).update({
      'savedGroupMemories': FieldValue.arrayUnion([memoryDocId]),
    });

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    }
  }

  void _skipToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    String memoryDocId = '${groupCode}_${adventureData['number']}';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Recuerdos del Grupo', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text('Estos son los recuerdos de tu última aventura en grupo', textAlign: TextAlign.center, style: TextStyle(color: Colors.amber.shade200, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('group_memories').doc(memoryDocId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF8E24AA)));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final Map<String, dynamic> photos = data['photos'] ?? {};

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.75),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final uid = members[index];
                    final photoUrl = photos[uid];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                      builder: (context, userSnap) {
                        final userData = userSnap.data?.data() as Map<String, dynamic>?;
                        final name = userData?['username'] ?? 'Aventurero';
                        return Container(
                          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF8E24AA).withOpacity(0.3))),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: photoUrl != null
                                      ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white30, size: 50)))
                                      : const Icon(Icons.sentiment_very_dissatisfied, color: Colors.white30, size: 60),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                              )
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () => _saveToAlbum(context),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('Guardar y Continuar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () => _skipToHome(context),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    icon: const Icon(Icons.close),
                    label: const Text('No Guardar', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}