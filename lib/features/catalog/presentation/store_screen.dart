import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/book.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/cart_icon_button.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/empty_state.dart';
import 'catalog_providers.dart';
import 'widgets/catalog_list_tile.dart';

/// The purchasable catalog — full book list with filters/sort, price, and
/// add-to-cart access. Distinct from Explore (search-first discovery).
class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _pickSort() {
    final current = ref.read(catalogSortProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: CatalogSort.values.map((sort) {
              return ListTile(
                leading: Icon(
                  sort == current ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: sort == current ? context.colors.ink : context.colors.textTertiary,
                ),
                title: Text('by ${sort.label}', style: TextStyle(color: context.colors.textPrimary)),
                onTap: () {
                  ref.read(catalogSortProvider.notifier).state = sort;
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(discoverFilterProvider);
    final sort = ref.watch(catalogSortProvider);
    final booksAsync = ref.watch(discoverBooksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Store'), actions: const [CartIconButton()]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search title, author...',
                prefixIcon: Icon(Icons.search_rounded, color: context.colors.textTertiary),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : Semantics(
                        button: true,
                        label: 'Clear search',
                        child: IconButton(
                          icon: Icon(Icons.close_rounded, color: context.colors.textTertiary),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(discoverFilterProvider.notifier).update(
                                  (s) => s.copyWith(searchQuery: ''),
                                );
                            setState(() {});
                          },
                        ),
                      ),
              ),
              onChanged: (value) {
                ref.read(discoverFilterProvider.notifier).update(
                      (s) => s.copyWith(searchQuery: value),
                    );
                setState(() {});
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: BookType.values.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return CategoryChip(
                    label: 'All',
                    selected: filter.type == null,
                    onTap: () => ref
                        .read(discoverFilterProvider.notifier)
                        .update((s) => s.copyWith(clearType: true)),
                  );
                }
                final type = BookType.values[i - 1];
                return CategoryChip(
                  label: type.label,
                  selected: filter.type == type,
                  onTap: () =>
                      ref.read(discoverFilterProvider.notifier).update((s) => s.copyWith(type: type)),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: booksAsync.when(
              data: (books) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${books.length} books', style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                  Semantics(
                    button: true,
                    label: 'Sort by ${sort.label}',
                    child: InkWell(
                      onTap: _pickSort,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('by ${sort.label}', style: TextStyle(color: context.colors.textPrimary, fontSize: 13)),
                            Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textPrimary, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              loading: () => const SizedBox(height: 20),
              error: (err, _) => const SizedBox(height: 20),
            ),
          ),
          Expanded(
            child: booksAsync.when(
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
                    return CatalogListTile(
                      book: book,
                      onTap: () => context.push('/store/book/${book.id}'),
                    );
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: context.colors.ink)),
              error: (err, _) => Center(
                child: Text('Could not load books.', style: TextStyle(color: context.colors.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
