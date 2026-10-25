import 'package:flutter/material.dart';

import '../theme/app_color_tokens.dart';

/// A section heading row with an optional trailing "See all" affordance and subtitle.
/// Used by catalog rails, the library screen, and similar list-of-cards layouts.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;

  /// Optional subtitle or AI/ML recommendation reason badge.
  final String? subtitle;

  /// Text for the trailing action, e.g. "See all". Leave null (with
  /// [onAction] set) for basis.png's icon-only chevron affordance.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAction != null)
            Semantics(
              button: true,
              label: 'See all $title',
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (actionLabel != null) ...[
                        Text(
                          actionLabel!,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.colors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
