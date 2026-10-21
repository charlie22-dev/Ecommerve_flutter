import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/book.dart';
import '../../../core/services/db.dart';
import '../data/supabase_book_repository.dart';
import '../domain/book_repository.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) => SupabaseBookRepository());

final sectionBooksProvider =
    StreamProvider.family<List<Book>, FeaturedSection>((ref, section) {
  return ref.watch(bookRepositoryProvider).watchSection(section);
});

/// Home's unfiltered "All Books" grid — independent of `discoverFilterProvider`
/// so browsing the Discover tab never changes what Home shows.
final allBooksProvider = StreamProvider<List<Book>>((ref) {
  return ref.watch(bookRepositoryProvider).watchCatalog(limit: 20);
});

class DiscoverFilter {
  const DiscoverFilter({this.type, this.searchQuery = ''});

  final BookType? type;
  final String searchQuery;

  DiscoverFilter copyWith({BookType? type, bool clearType = false, String? searchQuery}) {
    return DiscoverFilter(
      type: clearType ? null : (type ?? this.type),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final discoverFilterProvider = StateProvider<DiscoverFilter>((ref) => const DiscoverFilter());

enum CatalogSort {
  popularity,
  rating,
  newest;

  String get label => switch (this) {
        CatalogSort.popularity => 'Popularity',
        CatalogSort.rating => 'Rating',
        CatalogSort.newest => 'Newest',
      };
}

final catalogSortProvider = StateProvider<CatalogSort>((ref) => CatalogSort.popularity);

final discoverBooksProvider = StreamProvider<List<Book>>((ref) {
  final filter = ref.watch(discoverFilterProvider);
  final sort = ref.watch(catalogSortProvider);

  return ref
      .watch(bookRepositoryProvider)
      .watchCatalog(type: filter.type, searchQuery: filter.searchQuery)
      .map((books) {
    final sorted = [...books];
    switch (sort) {
      case CatalogSort.popularity:
        sorted.sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
      case CatalogSort.rating:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
      case CatalogSort.newest:
        sorted.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    }
    return sorted;
  });
});

final bookByIdProvider = FutureProvider.family<Book?, String>((ref, bookId) {
  return ref.watch(bookRepositoryProvider).getById(bookId);
});

/// Fetches the display name of the store that sells this book.
final storeNameProvider = FutureProvider.family<String, String>((ref, storeId) async {
  if (storeId.isEmpty) return 'BookVerse';
  final row = await db.from('stores').select('name').eq('id', storeId).maybeSingle();
  return row?['name'] as String? ?? 'BookVerse';
});

class ExploreCategoryPick {
  const ExploreCategoryPick({required this.genre, required this.book});
  final String genre;
  final Book book;
}

/// One representative cover per genre for Explore's "Explore by Categories"
/// rail — first match per genre out of a small recent sample, not a
/// separate query per genre.
final exploreCategoriesProvider = StreamProvider<List<ExploreCategoryPick>>((ref) {
  return ref.watch(bookRepositoryProvider).watchCatalog(limit: 40).map((books) {
    final seen = <String>{};
    final picks = <ExploreCategoryPick>[];
    for (final book in books) {
      for (final genre in book.genres) {
        if (seen.add(genre)) picks.add(ExploreCategoryPick(genre: genre, book: book));
      }
    }
    return picks;
  });
});
