import 'package:flutter/material.dart';

import '../theme/app_color_tokens.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? context.colors.ink : context.colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? context.colors.ink : context.colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? context.colors.onInk : context.colors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
