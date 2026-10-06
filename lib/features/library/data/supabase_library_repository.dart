import '../../../core/models/library_entry.dart';
import '../../../core/services/db.dart';
import '../domain/library_repository.dart';

class SupabaseLibraryRepository implements LibraryRepository {
  @override
  Stream<List<LibraryEntry>> watchShelf(String uid, ReadingShelf shelf) {
    return watchQuery(Tables.libraryEntries, () async {
      final rows = await db
          .from(Tables.libraryEntries)
          .select()
          .eq('user_id', uid)
          .eq('shelf', shelf.name)
          .order('updated_at', ascending: false);
      return rows.map(LibraryEntry.fromRow).toList();
    });
  }

  @override
  Stream<LibraryEntry?> watchEntry(String uid, String bookId) {
    return watchQuery(Tables.libraryEntries, () async {
      final row =
          await db.from(Tables.libraryEntries).select().eq('user_id', uid).eq('book_id', bookId).maybeSingle();
      return row == null ? null : LibraryEntry.fromRow(row);
    });
  }

  @override
  Future<void> upsertEntry(String uid, LibraryEntry entry) async {
    await db.from(Tables.libraryEntries).upsert(entry.toRow(uid));
  }

  @override
  Future<void> removeEntry(String uid, String bookId) async {
    await db.from(Tables.libraryEntries).delete().eq('user_id', uid).eq('book_id', bookId);
  }

  @override
  Future<void> toggleFavorite(String uid, String bookId, bool isFavorite) async {
    // Upsert with only these columns: an existing entry keeps its shelf and
    // progress; a new one gets the table defaults (wantToRead, 0%).
    await db.from(Tables.libraryEntries).upsert({'user_id': uid, 'book_id': bookId, 'is_favorite': isFavorite});
  }

  /// Progress + streak/completed-count bookkeeping run atomically in the
  /// `update_reading_progress` Postgres function (supabase/schema.sql).
  @override
  Future<void> updateProgress(
    String uid,
    String bookId, {
    required double progressPercent,
    required int currentChapter,
  }) async {
    await db.rpc('update_reading_progress', params: {
      'p_book_id': bookId,
      'p_progress_percent': progressPercent,
      'p_current_chapter': currentChapter,
    });
  }
}
