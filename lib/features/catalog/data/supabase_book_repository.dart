import '../../../core/models/book.dart';
import '../../../core/services/db.dart';
import '../domain/book_repository.dart';

class SupabaseBookRepository implements BookRepository {
  @override
  Stream<List<Book>> watchSection(FeaturedSection section, {int limit = 12}) {
    return watchQuery(Tables.books, () async {
      final rows = await db
          .from(Tables.books)
          .select()
          .contains('featured_sections', [section.name])
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(Book.fromRow).toList();
    });
  }

  /// Type and search filters run in Postgres (Firestore needed composite
  /// indexes for this, so it used to filter client-side).
  @override
  Stream<List<Book>> watchCatalog({BookType? type, String? searchQuery, int limit = 40}) {
    // Characters with meaning inside a PostgREST `or=(...)` filter.
    final search = searchQuery?.trim().replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();
    return watchQuery(Tables.books, () async {
      var query = db.from(Tables.books).select();
      if (type != null) query = query.eq('type', type.name);
      if (search != null && search.isNotEmpty) {
        query = query.or('title.ilike.%$search%,author.ilike.%$search%');
      }
      final rows = await query.order('created_at', ascending: false).limit(limit);
      return rows.map(Book.fromRow).toList();
    });
  }

  @override
  Future<Book?> getById(String bookId) async {
    final row = await db.from(Tables.books).select().eq('id', bookId).maybeSingle();
    return row == null ? null : Book.fromRow(row);
  }

  @override
  Future<String> save(Book book) async {
    if (book.id.isEmpty) {
      final row = await db.from(Tables.books).insert(book.toRow()).select('id').single();
      return row['id'] as String;
    }
    await db.from(Tables.books).update(book.toRow()).eq('id', book.id);
    return book.id;
  }

  @override
  Future<void> delete(String bookId) async {
    await db.from(Tables.books).delete().eq('id', bookId);
  }
}
