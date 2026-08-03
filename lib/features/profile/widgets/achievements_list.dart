import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/data/achievements_data.dart';
import '../../../core/models/achievement_definition.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/utils/achievement_mapper.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../providers/profile_provider.dart';

class AchievementsList extends StatelessWidget {
  final AchievementMode mode;

  const AchievementsList({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;
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

        final achColor = isUnlocked
            ? AchievementMapper.getColor(ach.colorName)
            : colors.muted;
        final achIcon = AchievementMapper.getIcon(ach.iconName);

        return GestureDetector(
          onTap: isUnlocked
              ? () {
                  if (!isEquipped && profileProvider.equippedPins.length >= 3) {
                    CustomSnackBar.showWarning(
                      context,
                      'Máximo 3 pines equipados',
                    );
                    return;
                  }
                  profileProvider.togglePin(ach.id, isEquipped);
                }
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isEquipped
                  ? colors.primary.withValues(alpha: 0.12)
                  : (isUnlocked ? colors.bg : colors.bg.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEquipped
                    ? colors.primary.withValues(alpha: 0.6)
                    : (isUnlocked
                        ? colors.muted.withValues(alpha: 0.2)
                        : colors.muted.withValues(alpha: 0.1)),
                width: isEquipped ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? achColor.withValues(alpha: 0.15)
                        : colors.muted.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    achIcon,
                    color: isUnlocked ? achColor : colors.muted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ach.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isUnlocked ? colors.text : colors.muted,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ach.rarityLabel,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ach.description,
                        style: TextStyle(
                          color: isUnlocked ? colors.text2 : colors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${ach.unlockPercentage}% de usuarios',
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  ${ach.categoryTag}',
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (!isUnlocked)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (currentValue / ach.requiredValue)
                                        .clamp(0.0, 1.0),
                                    minHeight: 4,
                                    backgroundColor:
                                        colors.muted.withValues(alpha: 0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$currentValue / ${ach.requiredValue}',
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isEquipped)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Equipado como pin',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isEquipped)
                  Icon(Icons.push_pin, color: colors.primary, size: 20)
                else if (isUnlocked)
                  const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 20)
                else
                  Icon(Icons.lock_outline, color: colors.muted, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}