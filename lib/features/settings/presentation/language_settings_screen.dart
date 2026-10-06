import 'package:flutter/material.dart';

import '../../../core/theme/app_color_tokens.dart';

/// Only English is actually wired up (no i18n/arb setup exists yet in this
/// project) — the other options are shown honestly as "coming soon" rather
/// than faking a language switch that wouldn't translate anything.
class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  static const _languages = ['English', 'Filipino', '日本語', '한국어', '中文'];
  String _selected = 'English';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Language Settings')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _languages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final language = _languages[i];
          final selected = language == _selected;
          final available = language == 'English';
          return Opacity(
            opacity: available ? 1 : 0.55,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (!available) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$language is coming soon.')));
                  return;
                }
                setState(() => _selected = language);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? colors.ink : colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(language, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15))),
                    if (selected) Icon(Icons.check_circle_rounded, color: colors.ink, size: 20)
                    else if (!available) Text('Coming soon', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
