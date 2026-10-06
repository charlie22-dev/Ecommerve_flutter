import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/book.dart';
import '../../../core/models/library_entry.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../data/supabase_library_repository.dart';
import '../domain/library_repository.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) => SupabaseLibraryRepository());

final shelfEntriesProvider = StreamProvider.family<List<LibraryEntry>, ReadingShelf>((ref, shelf) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(libraryRepositoryProvider).watchShelf(uid, shelf);
});

final libraryEntryProvider = StreamProvider.family<LibraryEntry?, String>((ref, bookId) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(libraryRepositoryProvider).watchEntry(uid, bookId);
});

final favoriteBookIdsProvider = Provider<Set<String>>((ref) {
  final favorites = ref.watch(shelfEntriesProvider(ReadingShelf.favorites)).value ?? const [];
  return favorites.map((e) => e.bookId).toSet();
});

class NowReading {
  const NowReading({required this.entry, required this.book});
  final LibraryEntry entry;
  final Book book;
}

/// The Home hero card's data: whichever book the user most recently made
/// progress on (shelfEntriesProvider already orders by `updatedAt` desc).
final nowReadingProvider = FutureProvider<NowReading?>((ref) async {
  final entries = await ref.watch(shelfEntriesProvider(ReadingShelf.currentlyReading).future);
  if (entries.isEmpty) return null;
  final entry = entries.first;
  final book = await ref.watch(bookRepositoryProvider).getById(entry.bookId);
  if (book == null) return null;
  return NowReading(entry: entry, book: book);
});

class LibraryActions {
  LibraryActions(this.ref);
  final Ref ref;

  String? get _uid => ref.read(authStateProvider).value?.uid;

  Future<void> addToShelf(String bookId, ReadingShelf shelf) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(libraryRepositoryProvider).upsertEntry(uid, LibraryEntry(bookId: bookId, shelf: shelf));
  }

  Future<void> updateProgress(String bookId, {required double progressPercent, required int currentChapter}) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(libraryRepositoryProvider).updateProgress(
          uid,
          bookId,
          progressPercent: progressPercent,
          currentChapter: currentChapter,
        );
  }

  Future<void> toggleFavorite(String bookId, bool isFavorite) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(libraryRepositoryProvider).toggleFavorite(uid, bookId, isFavorite);
  }

  Future<void> removeFromLibrary(String bookId) async {
    final uid = _uid;
    if (uid == null) return;
    await ref.read(libraryRepositoryProvider).removeEntry(uid, bookId);
  }
}

final libraryActionsProvider = Provider((ref) => LibraryActions(ref));
