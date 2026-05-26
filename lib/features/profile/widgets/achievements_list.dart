import 'package:flutter/material.dart';
import '../../../core/data/achievements_data.dart';
import '../../../core/models/achievement_definition.dart';
import '../../../core/utils/achievement_mapper.dart';
import '../providers/profile_provider.dart';
import 'package:provider/provider.dart';

class AchievementsList extends StatelessWidget {
  final AchievementMode mode;

  const AchievementsList({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final achievements = AchievementsData.getByMode(mode);

    return ListView.builder(
      padding: const EdgeInsets.only(top: 15, left: 20, right: 20, bottom: 30),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final ach = achievements[index];
        final currentValue = profileProvider.getCurrentValue(ach);
        final isUnlocked = currentValue >= ach.requiredValue;
        final isEquipped = profileProvider.equippedPins.contains(ach.id);
        final achColor = AchievementMapper.getColor(ach.colorName);
        final achIcon = AchievementMapper.getIcon(ach.iconName);

        return GestureDetector(
          onTap: isUnlocked ? () {
            if (!isEquipped && profileProvider.equippedPins.length >= 3) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Máximo 3 pines equipados')));
              return;
            }
            profileProvider.togglePin(ach.id, isEquipped);
          } : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isEquipped ? achColor.withValues(alpha: 0.1) : (isUnlocked ? Colors.grey.shade50 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isEquipped ? achColor.withValues(alpha: 0.5) : (isUnlocked ? Colors.grey.shade200 : Colors.grey.shade300),
                width: isEquipped ? 2 : 1
              )
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: isUnlocked ? achColor.withValues(alpha: 0.15) : Colors.grey.shade300, shape: BoxShape.circle),
                child: Icon(achIcon, color: isUnlocked ? achColor : Colors.grey.shade500, size: 22)
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ach.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isUnlocked ? Colors.black87 : Colors.grey)),
                  Text(ach.description, style: TextStyle(color: isUnlocked ? Colors.grey.shade600 : Colors.grey.shade500, fontSize: 12)),
                  if (!isUnlocked) Padding(padding: const EdgeInsets.only(top: 4), child: Text('$currentValue / ${ach.requiredValue}', style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)))
                  else if (isEquipped) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Equipado como pin', style: TextStyle(color: Color(0xFF9C27B0), fontSize: 11, fontWeight: FontWeight.bold)))
                ]
              )),
              if (isEquipped) const Icon(Icons.push_pin, color: Color(0xFF9C27B0), size: 20)
              else if (isUnlocked) const Icon(Icons.check_circle_outline, color: Colors.green, size: 20)
              else const Icon(Icons.lock_outline, color: Colors.grey, size: 20)
            ]),
          ),
        );
      },
    );
  }
}