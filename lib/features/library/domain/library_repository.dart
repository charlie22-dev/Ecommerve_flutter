import '../../../core/models/library_entry.dart';

/// Contract for managing user library shelves, reading status, and bookmarks.
abstract class LibraryRepository {
  Stream<List<LibraryEntry>> watchShelf(String uid, ReadingShelf shelf);

  Stream<LibraryEntry?> watchEntry(String uid, String bookId);

  Future<void> upsertEntry(String uid, LibraryEntry entry);

  Future<void> removeEntry(String uid, String bookId);

  Future<void> toggleFavorite(String uid, String bookId, bool isFavorite);

  Future<void> updateProgress(
    String uid,
    String bookId, {
    required double progressPercent,
    required int currentChapter,
  });
}
