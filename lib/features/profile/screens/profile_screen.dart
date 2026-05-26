import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../../../core/models/achievement_definition.dart';
import '../../../core/data/achievements_data.dart';
import '../../../core/utils/achievement_mapper.dart';
import '../widgets/achievements_list.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  ImageProvider? _getImage(ProfileProvider provider) {
    if (provider.selectedImageBytes != null) return MemoryImage(provider.selectedImageBytes!);
    if (provider.photoUrl != null) return NetworkImage(provider.photoUrl!);
    return null;
  }

  AchievementDefinition? _getAchById(String id) {
    for (var mode in AchievementMode.values) {
      for (var ach in AchievementsData.getByMode(mode)) {
        if (ach.id == id) return ach;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProfileProvider>(context);

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF1976D2))));
    }

    final backgroundImage = _getImage(provider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: provider.isUploadingPhoto ? null : provider.pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: const Color(0xFF1976D2),
                          backgroundImage: backgroundImage,
                          child: backgroundImage == null
                              ? Text(provider.initials, style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        if (provider.isUploadingPhoto)
                          Container(
                            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(40),
                            child: const CircularProgressIndicator(color: Colors.white),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Color(0xFF1976D2), shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          )
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(provider.userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                  Text('Nivel ${provider.level}', style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 15),
                  LinearProgressIndicator(
                    value: provider.progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${provider.exp} EXP', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text('${provider.nextExp} EXP', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard('Solitario', provider.soloDates, Icons.person, Colors.blue),
                      if (provider.isLinked) _buildStatCard('Pareja', provider.coupleDates, Icons.favorite, Colors.pink),
                      _buildStatCard('Grupo', provider.groupOutings, Icons.group, Colors.purple),
                    ],
                  ),
                  if (provider.equippedPins.isNotEmpty) ...[
                    const Divider(height: 30),
                    const Text('Mis Pines Equipados', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: provider.equippedPins.map((pinId) {
                        final ach = _getAchById(pinId);
                        if (ach == null) return const SizedBox.shrink();
                        final color = AchievementMapper.getColor(ach.colorName);
                        final icon = AchievementMapper.getIcon(ach.iconName);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: color.withOpacity(0.5), width: 2)
                                ),
                                child: Icon(icon, color: color, size: 28),
                              ),
                              const SizedBox(height: 4),
                              Text(ach.title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis)
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 20),
            
            DefaultTabController(
              length: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Material(
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                      child: TabBar(
                        labelColor: Color(0xFF1976D2),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Color(0xFF1976D2),
                        tabs: [
                          Tab(text: 'General'),
                          Tab(text: 'Solitario'),
                          Tab(text: 'Pareja'),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 300,
                      child: TabBarView(
                        children: [
                          AchievementsList(mode: AchievementMode.general),
                          AchievementsList(mode: AchievementMode.solo),
                          AchievementsList(mode: AchievementMode.couple),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 25),
        ),
        const SizedBox(height: 5),
        Text(value.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
      ],
    );
  }
}