import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/group_provider.dart';
import 'group_room.dart';
import 'group_memory_board_screen.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class GroupLobby extends StatelessWidget {
  const GroupLobby({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = authProvider.user!.uid;

    return ChangeNotifierProvider(
      create: (_) => GroupProvider(Provider.of<AuthProvider>(context, listen: false)),
      child: Consumer<GroupProvider>(
        builder: (context, groupProvider, _) {
          
          final bool isInRoom = groupProvider.currentGroupCode != null;

          return Scaffold(
            backgroundColor: const Color(0xFFF3E5F5),
            // Ocultamos el AppBar si ya estamos dentro de la sala de espera
            appBar: isInRoom ? null : AppBar(
              title: const Text('Aventura Grupal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF8E24AA),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isInRoom 
                ? GroupRoom(key: ValueKey(groupProvider.currentGroupCode), groupCode: groupProvider.currentGroupCode!)
                : FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(myUid).get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF8E24AA)));
                      }

                      final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final List<dynamic> dismissedMemories = userData['dismissedGroupMemories'] ?? [];

                      return FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance.collection('group_memories').where('members', arrayContains: myUid).orderBy('timestamp', descending: true).limit(1).get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF8E24AA)));
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return _buildMainContent(context, groupProvider, null, false);
                          }

                          final lastDoc = snapshot.data!.docs.first;
                          final String memoryDocId = lastDoc.id;
                          final memoryData = lastDoc.data() as Map<String, dynamic>?;
                          final List<dynamic> savedBy = List<dynamic>.from(memoryData?['savedBy'] ?? []);

                          bool wasSaved = savedBy.contains(myUid);
                          bool wasDismissed = dismissedMemories.contains(memoryDocId);

                          if (wasDismissed) {
                            return _buildMainContent(context, groupProvider, null, false);
                          }

                          return _buildMainContent(context, groupProvider, lastDoc, wasSaved);
                        },
                      );
                    },
                  ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, GroupProvider groupProvider, DocumentSnapshot? lastAdventureDoc, bool wasSaved) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        children: [
          const Icon(Icons.groups_rounded, size: 80, color: Color(0xFF8E24AA)),
          const SizedBox(height: 10),
          const Text('¡La unión hace la fuerza!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF8E24AA))),
          const SizedBox(height: 20),
          
          if (lastAdventureDoc != null) ...[
            Text(wasSaved ? 'Hace poco disfrutaron:' : 'Tu última aventura:', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            _buildLastAdventureCard(context, lastAdventureDoc, wasSaved),
            const SizedBox(height: 30),
          ],
          
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: groupProvider.isLoading ? null : () async {
                final code = await groupProvider.createGroup();
                if (code == null && context.mounted) {
                  CustomSnackBar.showError(context, 'Error al crear grupo');
                }
              },
              child: groupProvider.isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Iniciar Nueva Expedición', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity, height: 55,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8E24AA), side: const BorderSide(color: Color(0xFF8E24AA), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: groupProvider.isLoading ? null : () => _showJoinDialog(context, groupProvider),
              child: const Text('Unirse a Grupo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastAdventureCard(BuildContext context, DocumentSnapshot doc, bool wasSaved) {
    final data = doc.data() as Map<String, dynamic>;
    final String title = data['adventure_title'] ?? 'Aventura';
    final String emoji = data['emoji'] ?? '👥';
    final Map<String, dynamic> photos = data['photos'] ?? {};
    final Timestamp? timestamp = data['timestamp'];
    final String dateStr = timestamp != null ? "${timestamp.toDate().day.toString().padLeft(2, '0')}/${timestamp.toDate().month.toString().padLeft(2, '0')}/${timestamp.toDate().year}" : 'Fecha desconocida';
    final int membersCount = (data['members'] as List?)?.length ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => GroupMemoryBoardScreen(
          groupCode: data['coupleDocId'] ?? doc.id.split('_').first, 
          adventureData: {'title': title, 'emoji': emoji, 'number': int.tryParse(data['id_adventure'] ?? '0') ?? 0}, 
          members: List<String>.from(data['members'] ?? []),
          isReviewingPastMemory: wasSaved,
        )));
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20), 
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          border: wasSaved ? Border.all(color: const Color(0xFF8E24AA).withOpacity(0.3), width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 15),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF8E24AA))),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                        Icon(Icons.people_outline, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('$membersCount personas', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      ],
                    )
                  ],
                )),
                const Icon(Icons.chevron_right, color: Color(0xFF8E24AA))
              ],
            ),
            if (wasSaved) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera_front, color: Color(0xFF8E24AA), size: 16),
                    const SizedBox(width: 6),
                    Text('${photos.length} fotos subidas', style: const TextStyle(color: Color(0xFF8E24AA), fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    Text('¡Repitan pronto!', style: TextStyle(color: Colors.purple.shade300, fontStyle: FontStyle.italic, fontSize: 12)),
                  ],
                ),
              )
            ] else ...[
              const SizedBox(height: 8),
              Text('${photos.length} fotos subidas', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ]
          ],
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context, GroupProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ingresar Código', textAlign: TextAlign.center),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: InputDecoration(hintText: 'ABC123', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), counterText: ""),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), 
            onPressed: () async { 
              Navigator.pop(_); 
              final error = await provider.joinGroup(controller.text.trim()); 
              if (error != null && context.mounted) { 
                CustomSnackBar.showError(context, error); 
              } 
            }, 
            child: const Text('Unirse', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }
}