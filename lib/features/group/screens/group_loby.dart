import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/group_provider.dart';
import 'group_room.dart';
import 'group_memory_board_screen.dart';

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
          if (groupProvider.currentGroupCode != null) {
            return GroupRoom(groupCode: groupProvider.currentGroupCode!);
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF3E5F5),
            appBar: AppBar(
              title: const Text('Aventura Grupal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF8E24AA),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('group_memories').where('members', arrayContains: myUid).orderBy('timestamp', descending: true).limit(1).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF8E24AA)));
                }

                final hasLastAdventure = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    children: [
                      const Icon(Icons.groups_rounded, size: 80, color: Color(0xFF8E24AA)),
                      const SizedBox(height: 10),
                      const Text('¡La unión hace la fuerza!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF8E24AA))),
                      const SizedBox(height: 20),
                      
                      if (hasLastAdventure) ...[
                        const Text('Tu última aventura:', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        _buildLastAdventureCard(context, snapshot.data!.docs.first),
                        const SizedBox(height: 30),
                      ],
                      
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          onPressed: groupProvider.isLoading ? null : () async {
                            final code = await groupProvider.createGroup();
                            if (code == null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al crear grupo'), backgroundColor: Colors.redAccent));
                            }
                          },
                          icon: groupProvider.isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.add_circle_outline, color: Colors.white),
                          label: const Text('Iniciar Nueva Expedición', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8E24AA), side: const BorderSide(color: Color(0xFF8E24AA), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          onPressed: groupProvider.isLoading ? null : () => _showJoinDialog(context, groupProvider),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Unirse a Grupo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLastAdventureCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String title = data['adventure_title'] ?? 'Aventura';
    final String emoji = data['emoji'] ?? '👥';
    final Map<String, dynamic> photos = data['photos'] ?? {};
    
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => GroupMemoryBoardScreen(
          groupCode: data['coupleDocId'] ?? doc.id.split('_').first, 
          adventureData: {'title': title, 'emoji': emoji, 'number': int.tryParse(data['id_adventure'] ?? '0') ?? 0}, 
          members: List<String>.from(data['members'] ?? []),
        )));
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 15),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF8E24AA))),
                Text('${photos.length} fotos subidas', style: const TextStyle(color: Colors.grey)),
              ],
            )),
            const Icon(Icons.chevron_right, color: Color(0xFF8E24AA))
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
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () async { Navigator.pop(_); final error = await provider.joinGroup(controller.text.trim()); if (error != null && context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.redAccent)); }}, child: const Text('Unirse', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}