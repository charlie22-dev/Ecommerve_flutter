import 'package:flutter/material.dart';

import '../theme/app_color_tokens.dart';

class ReadingProgressBar extends StatelessWidget {
  const ReadingProgressBar({
    super.key,
    required this.percent,
    this.height = 6,
    this.color,
    this.showLabel = false,
  });

  final double percent; // 0..100
  final double height;

  /// Defaults to the theme's `ink` token — kept nullable (rather than a
  /// `= AppColors.ink` default) because a constructor default must be a
  /// compile-time constant, and this needs to resolve per-theme instead.
  final Color? color;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clamped = percent.clamp(0, 100) / 100;

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: clamped.toDouble(),
        minHeight: height,
        backgroundColor: colors.border,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? colors.ink),
      ),
    );

    if (!showLabel) return bar;

    return Row(
      children: [
        Expanded(child: bar),
        const SizedBox(width: 8),
        Text(
          '${percent.round()}%',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
