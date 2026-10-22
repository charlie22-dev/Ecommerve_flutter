import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/library_entry.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/reading_progress_bar.dart';
import '../../catalog/presentation/catalog_providers.dart';
import 'bookmark_providers.dart';
import 'collection_providers.dart';
import 'widgets/collection_card.dart';
import 'widgets/create_collection_sheet.dart';

extension on BookmarkTab {
  String get label => switch (this) {
        BookmarkTab.all => 'All',
        BookmarkTab.recent => 'Recent',
        BookmarkTab.pinned => 'Pinned',
        BookmarkTab.toRead => 'To Read',
        BookmarkTab.inProgress => 'In Progress',
      };
}

final _selectedTabProvider = StateProvider<BookmarkTab>((ref) => BookmarkTab.all);

/// "My Bookmarks" — matches main_basis.png's Library tab: chip-filtered
/// saved books plus a "Recently Saved" collections row, with a floating
/// "+" to start a new collection.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_selectedTabProvider);
    final entries = ref.watch(bookmarkEntriesProvider(selectedTab));
    final collectionsAsync = ref.watch(collectionsProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 8, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Back',
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
                            onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
                          ),
                        ),
                        Text('My Bookmarks', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                    Semantics(
                      button: true,
                      label: 'New collection',
                      child: IconButton(
                        onPressed: () => CreateCollectionSheet.show(context),
                        icon: const Icon(Icons.more_horiz_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: BookmarkTab.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final tab = BookmarkTab.values[i];
                    return CategoryChip(
                      label: tab.label,
                      selected: selectedTab == tab,
                      onTap: () => ref.read(_selectedTabProvider.notifier).state = tab,
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: collectionsAsync.when(
                data: (collections) {
                  if (collections.isEmpty) return const SizedBox(height: 16);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                        child: Text('Recently Saved', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: collections.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, i) => SizedBox(
                            width: 280,
                            child: CollectionCard(
                              collection: collections[i],
                              onTap: () => context.push('/library/collection/${collections[i].id}'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 16),
                error: (err, _) => const SizedBox(height: 16),
              ),
            ),
            if (entries.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.bookmark_border_rounded,
                  title: 'Nothing here yet',
                  message: 'Books you save or start reading will show up here.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _BookmarkTile(entry: entries[i]),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Semantics(
        button: true,
        label: 'New collection',
        child: FloatingActionButton(
          backgroundColor: context.colors.ink,
          foregroundColor: context.colors.onInk,
          onPressed: () => CreateCollectionSheet.show(context),
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }
}

class _BookmarkTile extends ConsumerWidget {
  const _BookmarkTile({required this.entry});
  final BookmarkEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookByIdProvider(entry.bookId));

    return bookAsync.when(
      data: (book) {
        if (book == null) return const SizedBox.shrink();
        return InkWell(
          onTap: () => context.push('/library/book/${book.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 56, height: 84, child: BookCoverImage(url: book.coverUrl)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(book.author, style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      if (entry.shelf != null && entry.shelf != ReadingShelf.wantToRead)
                        ReadingProgressBar(percent: entry.progressPercent, showLabel: true)
                      else if (entry.shelf != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: context.colors.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(entry.shelf!.label, style: TextStyle(color: context.colors.textSecondary, fontSize: 11)),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.bookmark_rounded, color: context.colors.ink, size: 18),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(height: 84),
      error: (err, _) => const SizedBox.shrink(),
    );
  }
}
