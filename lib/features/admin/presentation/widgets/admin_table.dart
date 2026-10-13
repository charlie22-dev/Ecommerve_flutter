import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_color_tokens.dart';

/// The admin's desktop table, styled like the rest of BookVerse: a bordered
/// surface card, muted header, and a quiet hover highlight on clickable rows.
/// Phones keep each screen's card list instead.
class AdminTable extends StatelessWidget {
  const AdminTable({super.key, required this.columns, required this.rows});

  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: colors.borderSubtle),
              child: DataTable(
                showCheckboxColumn: false,
                headingRowHeight: 44,
                dataRowMinHeight: 60,
                dataRowMaxHeight: 76,
                horizontalMargin: 16,
                columnSpacing: 24,
                headingRowColor: WidgetStatePropertyAll(colors.surfaceMuted),
                headingTextStyle: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                dataTextStyle: TextStyle(color: colors.textPrimary, fontSize: 13),
                columns: columns,
                rows: rows,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A clickable row with the shared hover color.
DataRow adminRow(BuildContext context, {required List<DataCell> cells, VoidCallback? onTap}) {
  final colors = context.colors;
  return DataRow(
    onSelectChanged: onTap == null ? null : (_) => onTap(),
    color: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.hovered) ? colors.surfaceMuted.withValues(alpha: 0.6) : null,
    ),
    cells: cells,
  );
}

/// Name + secondary line, the standard "who/what" cell.
class TwoLineCell extends StatelessWidget {
  const TwoLineCell(this.title, this.subtitle, {super.key, this.leading});

  final String title;
  final String subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700)),
        if (subtitle.isNotEmpty)
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textTertiary, fontSize: 12)),
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: leading == null
          ? text
          : Row(mainAxisSize: MainAxisSize.min, children: [leading!, const SizedBox(width: 10), Flexible(child: text)]),
    );
  }
}

/// A person's or store's photo, or else a colored initial. The color comes
/// from the name, so the same customer always gets the same theme accent.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.name, {super.key, this.photoUrl, this.radius = 16});
  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = [colors.accentBlue, colors.accentOrange, colors.success, colors.info, colors.star];
    final color = palette[name.hashCode.abs() % palette.length];
    final url = photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      foregroundImage: url == null || url.isEmpty ? null : CachedNetworkImageProvider(url),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: radius * 0.8),
      ),
    );
  }
}

/// Search box used above admin tables and lists.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search_rounded)),
    );
  }
}
