import 'dart:math' as math;

import '../../../core/models/book.dart';
import '../../../core/models/library_entry.dart';
import '../../../core/models/order.dart';

/// The learned preference vector and feature weights for a user.
class UserPreferenceProfile {
  UserPreferenceProfile({
    Map<BookType, double>? typeScores,
    Map<String, double>? genreScores,
    Map<String, double>? authorScores,
    Set<String>? purchasedBookIds,
    this.primaryRecommendationReason,
  })  : typeScores = typeScores ?? {},
        genreScores = genreScores ?? {},
        authorScores = authorScores ?? {},
        purchasedBookIds = purchasedBookIds ?? {};

  final Map<BookType, double> typeScores;
  final Map<String, double> genreScores;
  final Map<String, double> authorScores;
  final Set<String> purchasedBookIds;
  final String? primaryRecommendationReason;

  bool get hasSufficientHistory =>
      purchasedBookIds.isNotEmpty || typeScores.isNotEmpty || genreScores.isNotEmpty;
}

/// Content-Based Recommendation & Machine Learning Ranking Engine.
///
/// Features:
/// - Recency-decayed feature vector extraction from past purchase orders.
/// - Multi-attribute affinity scoring (Book Type, Genres, Author, Tags).
/// - Purchase penalty so users discover fresh books rather than already-bought titles.
/// - Bayesian quality prior (ratings and rating counts) to balance popularity and relevance.
/// - Cold-start fallback to curated For-You / trending books.
class RecommendationEngine {
  const RecommendationEngine();

  /// Builds a preference profile from the user's purchase orders and library entries.
  UserPreferenceProfile trainProfile({
    required List<Order> orders,
    required List<Book> allCatalogBooks,
    List<LibraryEntry> libraryEntries = const [],
  }) {
    final booksById = {for (final b in allCatalogBooks) b.id: b};
    final purchasedBookIds = <String>{};
    final typeScores = <BookType, double>{};
    final genreScores = <String, double>{};
    final authorScores = <String, double>{};

    final now = DateTime.now();

    // 1. Learn from purchase history (highest confidence signal)
    for (final order in orders) {
      final daysAgo = order.createdAt != null
          ? now.difference(order.createdAt!).inDays.clamp(0, 365)
          : 30;

      // Exponential recency decay: recent purchases have much higher impact
      // Day 0: 1.0, Day 7: ~0.75, Day 30: ~0.45, Day 90: ~0.20
      final recencyWeight = 1.0 / (1.0 + 0.045 * daysAgo);

      for (final item in order.items) {
        purchasedBookIds.add(item.bookId);
        final book = booksById[item.bookId];
        final quantity = item.quantity.clamp(1, 10);

        if (book != null) {
          _accumulateBookFeatures(
            book: book,
            weightMultiplier: 5.0 * recencyWeight * quantity,
            typeScores: typeScores,
            genreScores: genreScores,
            authorScores: authorScores,
          );
        } else {
          // Fallback heuristic from title matching if catalog cache didn't have ID
          final titleLower = item.title.toLowerCase();
          if (titleLower.contains('manga')) {
            typeScores[BookType.manga] = (typeScores[BookType.manga] ?? 0.0) + (5.0 * recencyWeight);
          } else if (titleLower.contains('novel')) {
            typeScores[BookType.novel] = (typeScores[BookType.novel] ?? 0.0) + (5.0 * recencyWeight);
          } else if (titleLower.contains('comic')) {
            typeScores[BookType.comic] = (typeScores[BookType.comic] ?? 0.0) + (5.0 * recencyWeight);
          }
        }
      }
    }

    // 2. Secondary signal: Reading shelf / Favorites (moderate confidence)
    for (final entry in libraryEntries) {
      final book = booksById[entry.bookId];
      if (book != null) {
        _accumulateBookFeatures(
          book: book,
          weightMultiplier: 1.5,
          typeScores: typeScores,
          genreScores: genreScores,
          authorScores: authorScores,
        );
      }
    }

    // 3. Formulate transparent ML explanation for the user
    String? reason;
    if (typeScores.isNotEmpty) {
      final sortedTypes = typeScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topType = sortedTypes.first.key;

      if (sortedTypes.first.value > 2.0 && topType != BookType.other && topType != BookType.book) {
        reason = 'Based on your recent interest in ${topType.label}';
      }
    }

    if (reason == null && genreScores.isNotEmpty) {
      final sortedGenres = genreScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topGenre = sortedGenres.first.key;
      reason = 'Recommended for your taste in $topGenre';
    }

    if (reason == null && purchasedBookIds.isNotEmpty) {
      reason = 'Inspired by your recent purchases';
    }

    return UserPreferenceProfile(
      typeScores: typeScores,
      genreScores: genreScores,
      authorScores: authorScores,
      purchasedBookIds: purchasedBookIds,
      primaryRecommendationReason: reason,
    );
  }

  void _accumulateBookFeatures({
    required Book book,
    required double weightMultiplier,
    required Map<BookType, double> typeScores,
    required Map<String, double> genreScores,
    required Map<String, double> authorScores,
  }) {
    // Type affinity (e.g. Manga, Novel, Manhwa)
    typeScores[book.type] = (typeScores[book.type] ?? 0.0) + (weightMultiplier * 1.5);

    // Genre affinities (e.g. Romance, Fantasy, Action)
    for (final genre in book.genres) {
      final key = genre.trim().toLowerCase();
      if (key.isNotEmpty) {
        genreScores[key] = (genreScores[key] ?? 0.0) + (weightMultiplier * 1.0);
      }
    }

    // Author affinity
    final authorKey = book.author.trim().toLowerCase();
    if (authorKey.isNotEmpty) {
      authorScores[authorKey] = (authorScores[authorKey] ?? 0.0) + (weightMultiplier * 1.2);
    }
  }

  /// Evaluates and scores all candidates to return the top personalized recommendations.
  List<Book> rankRecommendations({
    required UserPreferenceProfile profile,
    required List<Book> candidateBooks,
    int limit = 12,
  }) {
    if (candidateBooks.isEmpty) return const [];

    // Cold-start fallback: user has no orders or history yet
    if (!profile.hasSufficientHistory) {
      final curated = candidateBooks
          .where((b) => b.featuredSections.contains(FeaturedSection.forYou))
          .toList();
      if (curated.isNotEmpty) {
        return curated.take(limit).toList();
      }
      // Or fallback to highest rated
      final sorted = [...candidateBooks]..sort((a, b) => b.rating.compareTo(a.rating));
      return sorted.take(limit).toList();
    }

    // Scoring candidates
    final scored = <({Book book, double score})>[];

    for (final book in candidateBooks) {
      double score = 0.0;

      // 1. Purchase penalty: Prioritize new books the user hasn't bought yet
      final alreadyBought = profile.purchasedBookIds.contains(book.id);
      if (alreadyBought) {
        score -= 100.0;
      }

      // 2. Type Match (Manga vs Book vs Novel etc.)
      final typeAffinity = profile.typeScores[book.type] ?? 0.0;
      score += typeAffinity * 4.5;

      // 3. Genre Match (Cosine normalized)
      double genreAffinity = 0.0;
      for (final genre in book.genres) {
        final key = genre.trim().toLowerCase();
        genreAffinity += profile.genreScores[key] ?? 0.0;
      }
      if (book.genres.isNotEmpty) {
        genreAffinity = genreAffinity / math.sqrt(book.genres.length);
      }
      score += genreAffinity * 3.0;

      // 4. Author Match
      final authorAffinity = profile.authorScores[book.author.trim().toLowerCase()] ?? 0.0;
      score += authorAffinity * 2.5;

      // 5. Curated For-You baseline bonus
      if (book.featuredSections.contains(FeaturedSection.forYou)) {
        score += 2.0;
      }

      // 6. Quality & Popularity Prior
      final qualityScore = (book.rating / 5.0) * 1.5 + math.min(math.log(1.0 + book.ratingCount), 1.5);
      score += qualityScore;

      scored.add((book: book, score: score));
    }

    // Sort descending by calculated score
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((e) => e.book).take(limit).toList();
  }
}
