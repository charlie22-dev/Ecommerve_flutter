import '../../../core/models/book_collection.dart';

abstract class CollectionRepository {
  Stream<List<BookCollection>> watchCollections(String uid);

  Future<String> create(String uid, {required String title, required String description});

  Future<void> addBook(String uid, String collectionId, String bookId);

  Future<void> removeBook(String uid, String collectionId, String bookId);

  Future<void> delete(String uid, String collectionId);
}
