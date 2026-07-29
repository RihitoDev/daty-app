import 'package:flutter/material.dart';

class ContractRuleTile extends StatelessWidget {
  const ContractRuleTile({
    super.key,
    required this.value,
    required this.text,
    required this.accent,
    required this.textColor,
    required this.onChanged,
  });

  final bool value;
  final String text;
  final Color accent;
  final Color textColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      button: true,
      label: text,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  color: value ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: value ? accent : textColor.withValues(alpha: 0.42),
                    width: 1.6,
                  ),
                ),
                child: value
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    height: 1.32,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
