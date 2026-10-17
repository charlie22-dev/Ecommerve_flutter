import '../../../core/models/book_collection.dart';

/// Repository interface managing custom user book collections and reading lists.
abstract class CollectionRepository {
  Stream<List<BookCollection>> watchCollections(String uid);

  /// Creates a new custom user collection and returns its unique ID.
  Future<String> create(String uid, {required String title, required String description});

  Future<void> addBook(String uid, String collectionId, String bookId);

  Future<void> removeBook(String uid, String collectionId, String bookId);

  Future<void> delete(String uid, String collectionId);
}
