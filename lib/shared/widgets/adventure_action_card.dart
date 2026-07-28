import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'pressable_scale.dart';

class AdventureActionCard extends StatelessWidget {
  const AdventureActionCard({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final AppCustomTheme theme;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final effectiveAccent = enabled ? accent : theme.muted;

    return PressableScale(
      onTap: onTap,
      semanticsLabel: '$title. $subtitle',
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.adventureGradient(effectiveAccent),
            stops: const [0, 0.56, 1],
          ),
          border: Border.all(
            color: Color.alphaBlend(
              effectiveAccent.withValues(alpha: theme.isDark ? 0.3 : 0.2),
              theme.outline,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadow,
              blurRadius: theme.isDark ? 22 : 18,
              offset: const Offset(0, 8),
            ),
            if (theme.isDark && enabled)
              BoxShadow(
                color: effectiveAccent.withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: -4,
              ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -48,
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: effectiveAccent.withValues(
                    alpha: theme.isDark ? 0.07 : 0.045,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          effectiveAccent.withValues(
                            alpha: enabled ? 0.28 : 0.12,
                          ),
                          effectiveAccent.withValues(
                            alpha: enabled ? 0.12 : 0.06,
                          ),
                        ],
                      ),
                      border: Border.all(
                        color: effectiveAccent.withValues(
                          alpha: enabled ? 0.24 : 0.1,
                        ),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 29,
                      color: effectiveAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.text2,
                            fontSize: 13,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: effectiveAccent,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
