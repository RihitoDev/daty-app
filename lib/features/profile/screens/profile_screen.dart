import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/profile_provider.dart';
import '../../../core/models/achievement_definition.dart';
import '../../../core/data/achievements_data.dart';
import '../../../core/utils/achievement_mapper.dart';
import '../widgets/achievements_list.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      profileProvider.startListeningToUserDoc();
    });
  }

  @override
  void dispose() {
    Provider.of<ProfileProvider>(context, listen: false)
        .stopListeningToUserDoc();
    super.dispose();
  }

  AchievementDefinition? _getAchById(String id) {
    for (var mode in AchievementMode.values) {
      for (var ach in AchievementsData.getByMode(mode)) {
        if (ach.id == id) return ach;
      }
    }
    return null;
  }

  void _showPinDetailModal(
      BuildContext context, AchievementDefinition ach, dynamic colors) {
    final profileProvider = context.read<ProfileProvider>();
    final achColor = AchievementMapper.getColor(ach.colorName);
    final achIcon = AchievementMapper.getIcon(ach.iconName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: achColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: achColor, width: 2),
              ),
              child: Icon(achIcon, color: achColor, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              ach.title,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Rareza: ${ach.rarityLabel}',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ach.categoryTag,
                    style: TextStyle(
                      color: colors.text2,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ach.description,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.text2, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Obtenido por el ${ach.unlockPercentage}% de los usuarios de Daty',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton.icon(
            onPressed: () {
              profileProvider.togglePin(ach.id, true);
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.push_pin_outlined, color: Colors.redAccent),
            label: const Text(
              'Desequipar Pin',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;
    final provider = Provider.of<ProfileProvider>(context);

    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          'Mi Perfil',
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.card,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. Cabecera con Avatar, Nombre, Nivel y Rango
            Container(
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: provider.isUploadingPhoto
                        ? null
                        : () => provider.pickAndUploadImage(context),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: colors.primary,
                          child: provider.selectedImageBytes != null
                              ? ClipOval(
                                  child: Image.memory(
                                    provider.selectedImageBytes!,
                                    fit: BoxFit.cover,
                                    width: 110,
                                    height: 110,
                                  ),
                                )
                              : provider.photoUrl != null
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: provider.photoUrl!,
                                        fit: BoxFit.cover,
                                        width: 110,
                                        height: 110,
                                        placeholder: (_, __) => Text(
                                          provider.initials,
                                          style: const TextStyle(
                                            fontSize: 40,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => Text(
                                          provider.initials,
                                          style: const TextStyle(
                                            fontSize: 40,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      provider.initials,
                                      style: const TextStyle(
                                        fontSize: 40,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                        ),
                        if (provider.isUploadingPhoto)
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(40),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colors.card,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    provider.userName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                  if (provider.statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${provider.statusMessage}"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: colors.text2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Nivel ${provider.level} • ${provider.rankTitle}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  LinearProgressIndicator(
                    value: provider.progress,
                    minHeight: 10,
                    backgroundColor: colors.bg,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${provider.exp} EXP',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.muted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${provider.nextExp} EXP',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.muted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // 2. Tarjeta de Días Juntos (Solo si está vinculado)
            if (provider.isLinked) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withValues(alpha: 0.15),
                      colors.card,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${provider.daysTogether} días compartiendo aventuras',
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Construyendo historias memorables juntos',
                            style: TextStyle(color: colors.text2, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
            ],

            // 3. Estadísticas de Aventuras y Fotos
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Solitario',
                        provider.soloDates,
                        Icons.person,
                        colors.primary,
                        colors,
                      ),
                      _buildStatCard(
                        'Grupo',
                        provider.groupOutings,
                        Icons.group,
                        colors.primary,
                        colors,
                      ),
                      _buildStatCard(
                        'Fotos',
                        provider.totalPhotosCount,
                        Icons.photo_library_rounded,
                        colors.primary,
                        colors,
                      ),
                    ],
                  ),
                  if (provider.equippedPins.isNotEmpty) ...[
                    Divider(height: 30, color: colors.muted.withValues(alpha: 0.2)),
                    Text(
                      'Mis Pines Equipados (Toca para ver detalle)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.text2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: provider.equippedPins.map((pinId) {
                        final ach = _getAchById(pinId);
                        if (ach == null) return const SizedBox.shrink();
                        final achColor = AchievementMapper.getColor(ach.colorName);
                        final icon = AchievementMapper.getIcon(ach.iconName);
                        return InkWell(
                          onTap: () => _showPinDetailModal(context, ach, colors),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: achColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: achColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(icon, color: achColor, size: 28),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ach.title,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colors.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Colección de Logros
            DefaultTabController(
              length: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: colors.card,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                      child: TabBar(
                        labelColor: colors.primary,
                        unselectedLabelColor: colors.muted,
                        indicatorColor: colors.primary,
                        isScrollable: true,
                        tabs: const [
                          Tab(text: 'General'),
                          Tab(text: 'Solitario'),
                          Tab(text: 'Pareja'),
                          Tab(text: 'Grupo'),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 320,
                      child: TabBarView(
                        children: [
                          AchievementsList(mode: AchievementMode.general),
                          AchievementsList(mode: AchievementMode.solo),
                          AchievementsList(mode: AchievementMode.couple),
                          AchievementsList(mode: AchievementMode.group),
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

  Widget _buildStatCard(
    String title,
    int value,
    IconData icon,
    Color color,
    dynamic colors,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 5),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: colors.text2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
