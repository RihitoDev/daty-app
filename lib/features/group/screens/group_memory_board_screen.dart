import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/screens/home_screen.dart';

class GroupMemoryBoardScreen extends StatelessWidget {
  final String groupCode;
  final Map<String, dynamic> adventureData;
  final List<String> members;
  final bool isReviewingPastMemory;

  const GroupMemoryBoardScreen({
    super.key,
    required this.groupCode,
    required this.adventureData,
    required this.members,
    this.isReviewingPastMemory = false,
  });

  Future<Map<String, String?>> _fetchMemberNames(List<String> uids) async {
    final Map<String, String?> names = {};
    final futures = uids.map((uid) async {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        names[uid] = doc.data()?['username'] as String?;
      } else {
        names[uid] = null;
      }
    });
    await Future.wait(futures);
    return names;
  }

  Future<void> _saveToAlbum(BuildContext context) async {
    final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
    String memoryDocId = '${groupCode}_${adventureData['number']}';

    final WriteBatch batch = FirebaseFirestore.instance.batch();
    batch.update(
      FirebaseFirestore.instance.collection('group_memories').doc(memoryDocId),
      {'savedBy': FieldValue.arrayUnion([myUid])},
    );
    batch.update(
      FirebaseFirestore.instance.collection('users').doc(myUid),
      {'dismissedGroupMemories': FieldValue.arrayRemove([memoryDocId])},
    );
    await batch.commit();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    }
  }

  Future<void> _skipToHome(BuildContext context) async {
    final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
    String memoryDocId = '${groupCode}_${adventureData['number']}';
    
    await FirebaseFirestore.instance.collection('users').doc(myUid).update({
      'dismissedGroupMemories': FieldValue.arrayUnion([memoryDocId]),
    });

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String memoryDocId = '${groupCode}_${adventureData['number']}';
    const Color primaryColor = Color(0xFF8E24AA);

    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: const Color(0xFF1A0515), 
      appBar: AppBar(
        title: const Text('Recuerdos del Grupo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent, 
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A0515),
              Color(0xFF3B0A30),
              Color(0xFF1A0515),
            ],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
              child: Text(
                isReviewingPastMemory 
                  ? 'Reviviendo los buenos momentos de esta expedición' 
                  : 'Estos son los recuerdos de tu última aventura en grupo', 
                textAlign: TextAlign.center, 
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9), 
                  fontSize: 18, 
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                )
              ),
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

                  return FutureBuilder<Map<String, String?>>(
                    future: _fetchMemberNames(members),
                    builder: (context, namesSnap) {
                      final memberNames = namesSnap.data ?? {};

                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, 
                          crossAxisSpacing: 20, 
                          mainAxisSpacing: 20, 
                          childAspectRatio: 0.75
                        ),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final uid = members[index];
                          final photoUrl = photos[uid];
                          final name = memberNames[uid] ?? 'Aventurero';
                          
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: primaryColor.withOpacity(0.4), width: 1.5),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 6.0),
                                        child: photoUrl != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(12), 
                                              child: CachedNetworkImage(
                                                imageUrl: photoUrl, 
                                                fit: BoxFit.cover, 
                                                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Color(0xFF8E24AA))),
                                                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24, size: 50)
                                              )
                                            )
                                          : Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black26,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.white10)
                                              ),
                                              child: const Icon(Icons.add_a_photo_outlined, color: Colors.white24, size: 50),
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Text(
                                        name, 
                                        textAlign: TextAlign.center, 
                                        style: const TextStyle(
                                          color: Colors.white, 
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 14
                                        ), 
                                        overflow: TextOverflow.ellipsis
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            
            Container(
              padding: EdgeInsets.only(
                left: 30, right: 30, top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20 
              ),
              child: isReviewingPastMemory 
                ? SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                      ),
                      child: const Text('Volver al Lobby', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, primaryColor.withOpacity(0.7)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => _saveToAlbum(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('Guardar y Continuar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: OutlinedButton(
                          onPressed: () => _skipToHome(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white54, 
                            side: const BorderSide(color: Colors.white24), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                          ),
                          child: const Text('No Guardar', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
            )
          ],
        ),
      ),
    );
  }
}