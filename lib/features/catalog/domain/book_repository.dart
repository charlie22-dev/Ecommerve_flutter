import '../../../core/models/book.dart';

abstract class BookRepository {
  Stream<List<Book>> watchSection(FeaturedSection section, {int limit = 12});

  Stream<List<Book>> watchCatalog({BookType? type, String? searchQuery, int limit = 40});

  Future<Book?> getById(String bookId);

  /// Creates (empty `book.id`) or updates (existing `book.id`) a catalog
  /// entry. Returns the row id. Admin-only — see the `books: admin write`
  /// policy in supabase/schema.sql.
  Future<String> save(Book book);

  /// Admin-only — see supabase/schema.sql.
  Future<void> delete(String bookId);
}
