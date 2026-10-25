import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/models/book.dart';
import 'package:my_app/core/models/order.dart';
import 'package:my_app/features/catalog/domain/recommendation_engine.dart';

void main() {
  group('RecommendationEngine (ML Content-Based)', () {
    const engine = RecommendationEngine();

    final mangaBook1 = Book(
      id: 'manga-1',
      title: 'Chainsaw Boy Vol. 1',
      author: 'Tatsuki F.',
      type: BookType.manga,
      genres: const ['Action', 'Supernatural'],
      rating: 4.8,
      ratingCount: 150,
    );

    final mangaBook2 = Book(
      id: 'manga-2',
      title: 'Jujutsu Realm Vol. 1',
      author: 'Gege A.',
      type: BookType.manga,
      genres: const ['Action', 'Fantasy'],
      rating: 4.7,
      ratingCount: 120,
    );

    final novelBook = Book(
      id: 'novel-1',
      title: 'Pride and Prejudice',
      author: 'Jane Austen',
      type: BookType.novel,
      genres: const ['Romance', 'Classic'],
      rating: 4.6,
      ratingCount: 300,
    );

    final textbook = Book(
      id: 'text-1',
      title: 'Calculus 101',
      author: 'James Stewart',
      type: BookType.textbook,
      genres: const ['Education', 'Math'],
      rating: 4.0,
      ratingCount: 50,
    );

    final allCatalog = [mangaBook1, mangaBook2, novelBook, textbook];

    test('cold-start returns candidates without crashing', () {
      final profile = engine.trainProfile(
        orders: const [],
        allCatalogBooks: allCatalog,
      );

      expect(profile.hasSufficientHistory, isFalse);
      expect(profile.primaryRecommendationReason, isNull);

      final recommendations = engine.rankRecommendations(
        profile: profile,
        candidateBooks: allCatalog,
      );

      expect(recommendations.isNotEmpty, isTrue);
    });

    test('user who bought Manga gets Manga recommendations prioritized with reason', () {
      final order = Order(
        id: 'ord-101',
        uid: 'user-1',
        items: [
          OrderLineItem(
            bookId: mangaBook1.id,
            title: mangaBook1.title,
            coverUrl: mangaBook1.coverUrl,
            unitPrice: 350.0,
            quantity: 2,
          ),
        ],
        subtotal: 700.0,
        shippingCost: 50.0,
        voucherCode: null,
        voucherDiscount: 0.0,
        total: 750.0,
        shippingAddress: null,
        shippingOptionId: 'std',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      );

      final profile = engine.trainProfile(
        orders: [order],
        allCatalogBooks: allCatalog,
      );

      // Verify preference profile learned Manga affinity
      expect(profile.hasSufficientHistory, isTrue);
      expect(profile.typeScores[BookType.manga]! > 0, isTrue);
      expect(profile.primaryRecommendationReason, contains('Manga'));

      final recommendations = engine.rankRecommendations(
        profile: profile,
        candidateBooks: allCatalog,
      );

      // Top recommendation should be the unpurchased Manga (mangaBook2)
      expect(recommendations.first.id, equals('manga-2'));
      expect(recommendations.first.type, equals(BookType.manga));

      // The purchased book should not be first due to already-bought penalty
      expect(recommendations.first.id, isNot(equals('manga-1')));
    });
  });
}
