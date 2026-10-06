import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/library_entry.dart';
import '../../wishlist/presentation/wishlist_providers.dart';
import 'library_providers.dart';

enum BookmarkTab { all, recent, pinned, toRead, inProgress }

class BookmarkEntry {
  const BookmarkEntry({required this.bookId, this.sortDate, this.shelf, this.progressPercent = 0});
  final String bookId;
  final DateTime? sortDate;
  final ReadingShelf? shelf;
  final double progressPercent;
}

/// Merges reading shelves + wishlist into the single "My Bookmarks" list
/// main_basis.png shows, filtered by the selected chip tab.
final bookmarkEntriesProvider = Provider.family<List<BookmarkEntry>, BookmarkTab>((ref, tab) {
  final wishlistIds = ref.watch(wishlistIdsProvider).value ?? const {};

  if (tab == BookmarkTab.pinned) {
    return wishlistIds.map((id) => BookmarkEntry(bookId: id)).toList();
  }

  final currentlyReading = ref.watch(shelfEntriesProvider(ReadingShelf.currentlyReading)).value ?? const [];
  if (tab == BookmarkTab.inProgress) {
    return currentlyReading
        .map((e) => BookmarkEntry(bookId: e.bookId, sortDate: e.updatedAt, shelf: e.shelf, progressPercent: e.progressPercent))
        .toList();
  }

  final wantToRead = ref.watch(shelfEntriesProvider(ReadingShelf.wantToRead)).value ?? const [];
  if (tab == BookmarkTab.toRead) {
    return wantToRead
        .map((e) => BookmarkEntry(bookId: e.bookId, sortDate: e.updatedAt, shelf: e.shelf, progressPercent: e.progressPercent))
        .toList();
  }

  final completed = ref.watch(shelfEntriesProvider(ReadingShelf.completed)).value ?? const [];
  final favorites = ref.watch(shelfEntriesProvider(ReadingShelf.favorites)).value ?? const [];

  final byId = <String, BookmarkEntry>{};
  for (final e in [...currentlyReading, ...wantToRead, ...completed, ...favorites]) {
    byId[e.bookId] = BookmarkEntry(bookId: e.bookId, sortDate: e.updatedAt, shelf: e.shelf, progressPercent: e.progressPercent);
  }
  for (final id in wishlistIds) {
    byId.putIfAbsent(id, () => BookmarkEntry(bookId: id));
  }

  final all = byId.values.toList();
  if (tab == BookmarkTab.recent) {
    all.sort((a, b) => (b.sortDate ?? DateTime(0)).compareTo(a.sortDate ?? DateTime(0)));
    return all.take(10).toList();
  }
  return all;
});
