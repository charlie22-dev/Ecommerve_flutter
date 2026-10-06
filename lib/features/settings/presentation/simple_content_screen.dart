import 'package:flutter/material.dart';

import '../../../core/theme/app_color_tokens.dart';

class ContentSection {
  const ContentSection(this.heading, this.body);
  final String heading;
  final String body;
}

/// A single reusable screen shape for Help Center / Community Rules /
/// Policies / About Us — a title and a list of heading+body sections,
/// styled with the app's normal typography instead of one-off screens per
/// row.
class SimpleContentScreen extends StatelessWidget {
  const SimpleContentScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<ContentSection> sections;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 20),
        itemBuilder: (context, i) {
          final section = sections[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(section.heading, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 6),
              Text(section.body, style: TextStyle(color: colors.textSecondary, fontSize: 13.5, height: 1.55)),
            ],
          );
        },
      ),
    );
  }
}
