import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/book.dart';
import '../../../core/models/library_entry.dart';
import '../../checkout/presentation/checkout_providers.dart';
import '../../library/presentation/library_providers.dart';
import '../domain/recommendation_engine.dart';
import 'catalog_providers.dart';

final recommendationEngineProvider = Provider<RecommendationEngine>((ref) {
  return const RecommendationEngine();
});

/// Computes the user's learned preference vector from past orders & reading activity.
final userPreferenceProfileProvider = Provider<UserPreferenceProfile>((ref) {
  final engine = ref.watch(recommendationEngineProvider);
  final orders = ref.watch(userOrdersProvider).value ?? const [];
  final catalog = ref.watch(allBooksProvider).value ?? const [];
  final readingEntries = ref.watch(shelfEntriesProvider(ReadingShelf.currentlyReading)).value ?? const [];

  return engine.trainProfile(
    orders: orders,
    allCatalogBooks: catalog,
    libraryEntries: readingEntries,
  );
});

/// Intelligent ML recommendation reason shown in the UI (e.g. "Because you recently bought Manga").
final recommendationReasonProvider = Provider<String?>((ref) {
  return ref.watch(userPreferenceProfileProvider).primaryRecommendationReason;
});

/// Personalized "For You" books stream, updated in real time as the user purchases books.
final personalizedForYouProvider = Provider<AsyncValue<List<Book>>>((ref) {
  final allBooksAsync = ref.watch(allBooksProvider);
  final profile = ref.watch(userPreferenceProfileProvider);
  final engine = ref.watch(recommendationEngineProvider);

  return allBooksAsync.whenData((candidates) {
    return engine.rankRecommendations(
      profile: profile,
      candidateBooks: candidates,
      limit: 10,
    );
  });
});
