import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DatyContractHeader extends StatelessWidget {
  const DatyContractHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.customTheme,
    required this.content,
    required this.actions,
    required this.onClose,
    required this.isComplete,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final AppCustomTheme customTheme;
  final Widget content;
  final Widget actions;
  final VoidCallback onClose;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        final mascotSize = isCompact ? 168.0 : 185.0;
        const mascotLeft = 0.0;
        final bubbleLeft = isCompact ? 28.0 : 44.0;
        final bubbleBottom = mascotSize + 10;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset((1 - value) * -18, (1 - value) * 8),
              child: child,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
        Positioned(
          left: mascotLeft,
          bottom: 0,
          child: Image.asset(
            'assets/images/mascot.png',
            width: mascotSize,
            height: mascotSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.sentiment_very_satisfied_rounded,
              color: accent,
              size: 160,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          margin: EdgeInsets.fromLTRB(bubbleLeft, 0, 4, bubbleBottom),
          padding: const EdgeInsets.fromLTRB(22, 16, 20, 20),
          decoration: BoxDecoration(
            color: customTheme.card,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: accent.withValues(alpha: isComplete ? 0.72 : 0.34),
              width: isComplete ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: accent, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: customTheme.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar contrato',
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, color: customTheme.text2),
                  ),
                ],
              ),
              Divider(color: accent.withValues(alpha: 0.2)),
              content,
              SizedBox(
                height: 30,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: isComplete
                        ? Row(
                            key: const ValueKey('complete'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: accent, size: 17),
                              const SizedBox(width: 6),
                              Text('¡Trato hecho!', style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 13)),
                            ],
                          )
                        : const SizedBox.shrink(key: ValueKey('incomplete')),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              actions,
            ],
          ),
        ),
        Positioned(
          left: bubbleLeft + 12,
          bottom: bubbleBottom - 9,
          child: _ThoughtDot(
            size: 17,
            fillColor: customTheme.card,
            borderColor: accent.withValues(alpha: isComplete ? 0.72 : 0.34),
          ),
        ),
        Positioned(
          left: bubbleLeft + 2,
          bottom: bubbleBottom - 34,
          child: _ThoughtDot(
            size: 12,
            fillColor: customTheme.card,
            borderColor: accent.withValues(alpha: isComplete ? 0.72 : 0.34),
          ),
        ),
        Positioned(
          left: bubbleLeft - 2,
          bottom: bubbleBottom - 54,
          child: _ThoughtDot(
            size: 8,
            fillColor: customTheme.card,
            borderColor: accent.withValues(alpha: isComplete ? 0.72 : 0.34),
          ),
        ),
            ],
          ),
        );
      },
    );
  }
}

class _ThoughtDot extends StatelessWidget {
  const _ThoughtDot({
    required this.size,
    required this.fillColor,
    required this.borderColor,
  });

  final double size;
  final Color fillColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 5,
          ),
        ],
      ),
    );
  }
}
