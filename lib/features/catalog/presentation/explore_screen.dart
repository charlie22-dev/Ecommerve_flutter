import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/book.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_card.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import 'catalog_providers.dart';
import 'recent_searches_provider.dart';
import 'widgets/catalog_list_tile.dart';

/// Search-first discovery — reached by tapping the search bar on Home (see
/// item 6): search-as-you-type with real inline results and a type filter,
/// falling back to recent searches / Trending / Explore-by-Categories when
/// there's no active query or filter. The filter icon used to just bounce
/// to the Store tab unconditionally, which is the "keeps going back to
/// store" bug — it now opens a real type-filter sheet and shows results
/// right here instead.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(discoverFilterProvider.notifier).update((s) => s.copyWith(searchQuery: value));
    setState(() {});
  }

  void _onSearchSubmitted(String term) {
    if (term.trim().isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(term);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(discoverFilterProvider.notifier).update((s) => s.copyWith(searchQuery: '', clearType: true));
    setState(() {});
  }

  void _pickTypeFilter() {
    final current = ref.read(discoverFilterProvider).type;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter by type', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CategoryChip(
                      label: 'All',
                      selected: current == null,
                      onTap: () {
                        ref.read(discoverFilterProvider.notifier).update((s) => s.copyWith(clearType: true));
                        Navigator.of(sheetContext).pop();
                        setState(() {});
                      },
                    ),
                    ...BookType.values.map(
                      (type) => CategoryChip(
                        label: type.label,
                        selected: current == type,
                        onTap: () {
                          ref.read(discoverFilterProvider.notifier).update((s) => s.copyWith(type: type));
                          Navigator.of(sheetContext).pop();
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filter = ref.watch(discoverFilterProvider);
    final isSearching = filter.searchQuery.trim().isNotEmpty || filter.type != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
                      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(color: colors.textPrimary),
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmitted,
                      decoration: InputDecoration(
                        hintText: 'Search books, authors, genres...',
                        prefixIcon: Icon(Icons.search_rounded, color: colors.textTertiary),
                        suffixIcon: isSearching
                            ? IconButton(
                                tooltip: 'Clear search',
                                icon: Icon(Icons.close_rounded, color: colors.textTertiary),
                                onPressed: _clearSearch,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    label: 'Filter by type',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickTypeFilter,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: filter.type != null ? colors.ink : colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: filter.type != null ? colors.ink : colors.border),
                        ),
                        child: Icon(Icons.tune_rounded, color: filter.type != null ? colors.onInk : colors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isSearching ? _SearchResults(filter: filter) : const _ExploreIdleContent(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.filter});
  final DiscoverFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(discoverBooksProvider);

    return booksAsync.when(
      data: (books) {
        if (books.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No books found',
            message: 'Try a different search term or category.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: books.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: context.colors.borderSubtle),
          itemBuilder: (context, i) {
            final book = books[i];
            return CatalogListTile(book: book, onTap: () => context.push('/explore/book/${book.id}'));
          },
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: context.colors.ink)),
      error: (err, _) => Center(
        child: Text('Could not load books.', style: TextStyle(color: context.colors.error)),
      ),
    );
  }
}

class _ExploreIdleContent extends ConsumerWidget {
  const _ExploreIdleContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentSearchesProvider);
    final trendingAsync = ref.watch(sectionBooksProvider(FeaturedSection.trending));
    final categoriesAsync = ref.watch(exploreCategoriesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        recentAsync.when(
          data: (recent) {
            if (recent.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Search', style: Theme.of(context).textTheme.titleMedium),
                    Semantics(
                      button: true,
                      label: 'Clear all recent searches',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => ref.read(recentSearchesProvider.notifier).clear(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Clear All', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recent
                      .map((term) => _RecentChip(
                            term: term,
                            onTap: (t) => ref.read(discoverFilterProvider.notifier).update((s) => s.copyWith(searchQuery: t)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (err, _) => const SizedBox.shrink(),
        ),
        SectionHeader(title: 'Trending This Week'),
        SizedBox(
          height: 300,
          child: trendingAsync.when(
            data: (books) {
              if (books.isEmpty) {
                return Center(
                  child: Text('No trending titles yet.', style: TextStyle(color: context.colors.textTertiary, fontSize: 13)),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: books.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => BookCard(
                  book: books[i],
                  onTap: () => context.push('/explore/book/${books[i].id}'),
                ),
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: context.colors.ink)),
            error: (err, _) => const SizedBox.shrink(),
          ),
        ),
        SectionHeader(title: 'Explore by Categories'),
        SizedBox(
          height: 300,
          child: categoriesAsync.when(
            data: (picks) {
              if (picks.isEmpty) {
                return Center(
                  child: Text('No categories yet.', style: TextStyle(color: context.colors.textTertiary, fontSize: 13)),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: picks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => BookCard(
                  book: picks[i].book,
                  badgeLabel: picks[i].genre,
                  onTap: () => context.push('/explore/book/${picks[i].book.id}'),
                ),
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: context.colors.ink)),
            error: (err, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _RecentChip extends ConsumerWidget {
  const _RecentChip({required this.term, required this.onTap});
  final String term;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onTap(term),
      child: Container(
        padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(term, style: TextStyle(color: context.colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            Semantics(
              button: true,
              label: 'Remove "$term" from recent searches',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => ref.read(recentSearchesProvider.notifier).remove(term),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close_rounded, size: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
