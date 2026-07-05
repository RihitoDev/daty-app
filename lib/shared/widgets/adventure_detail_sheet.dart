import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Bottom sheet que muestra el detalle de una aventura antes de empezarla.
/// Separado del widget principal para mantener adventure_map.dart limpio.
class AdventureDetailSheet {

  static void show({
    required BuildContext context,
    required Map<String, dynamic> adventure,
    required Color themeColor,
    required String mode,
    required DocumentReference progressDocRef,
    required Map<int, Map<String, dynamic>> adventuresCache,
    required void Function() onReroll,
    required void Function(Map<String, dynamic> adventure, List<int> availableIds) onStart,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StreamBuilder<DocumentSnapshot>(
          stream: progressDocRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            List<dynamic> path = List.from(data['adventurePath'] ?? []);
            int rerollsUsed = data['rerollsUsed'] ?? 0;
            int rerollsLeft = 2 - rerollsUsed;
            List<int> availableIds = adventuresCache.keys.where((id) => !path.contains(id)).toList();

            return ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212).withOpacity(0.85),
                    border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40, height: 5,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    height: 180, width: double.infinity, color: Colors.black26,
                                    child: Image.asset(
                                      'assets/images/adventures/${adventure['number']}.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.grey.shade800),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              Center(child: Text(adventure['title'] ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: themeColor))),
                              const SizedBox(height: 15),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _InfoChip(icon: Icons.category, text: adventure['category'] ?? 'General', themeColor: themeColor),
                                  const SizedBox(width: 10),
                                  _InfoChip(icon: Icons.timer, text: adventure['estimatedTime'] ?? '1 hora', themeColor: themeColor),
                                  const SizedBox(width: 10),
                                  _InfoChip(icon: Icons.attach_money, text: 'Nivel \$${adventure['costLevel'] ?? 1}', themeColor: themeColor),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text('Descripcion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                              const SizedBox(height: 5),
                              Text(adventure['description'] ?? '', style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.7))),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: themeColor.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Icon(Icons.emoji_events_outlined, color: themeColor, size: 20),
                                      const SizedBox(width: 6),
                                      Text('Reto', style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
                                    ]),
                                    const SizedBox(height: 5),
                                    Text(adventure['challenge'] ?? '', style: TextStyle(color: themeColor)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: double.infinity, height: 55,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    onStart(adventure, availableIds);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    elevation: 5, shadowColor: themeColor,
                                  ),
                                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                  label: const Text('Empezar Aventura', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              if (mode != 'group' && rerollsLeft > 0) ...[
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: onReroll,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(color: Colors.white24),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                    ),
                                    icon: const Icon(Icons.casino_outlined),
                                    label: Text(mode == 'couple'
                                      ? 'Cambiar (Compartido: $rerollsLeft restantes)'
                                      : 'Cambiar Aventura ($rerollsLeft restantes)'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color themeColor;

  const _InfoChip({required this.icon, required this.text, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: themeColor),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }
}