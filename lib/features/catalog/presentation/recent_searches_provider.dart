import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'recent_searches';
const _maxRecent = 8;

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesController, List<String>>(RecentSearchesController.new);

class RecentSearchesController extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? const [];
  }

  Future<void> add(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? const [];
    final updated = [trimmed, ...current.where((t) => t.toLowerCase() != trimmed.toLowerCase())]
        .take(_maxRecent)
        .toList();
    state = AsyncData(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, updated);
  }

  Future<void> remove(String term) async {
    final updated = (state.value ?? const []).where((t) => t != term).toList();
    state = AsyncData(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, updated);
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
