import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/book.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/book_card.dart';
import '../../../../core/widgets/section_header.dart';
import 'feature_book_card.dart';

/// A horizontally-scrolling "Now Reading / For You / Trending / New
/// Releases" rail. Renders as a sliver so `HomeScreen` can stack several of
/// these inside one `CustomScrollView`.
class BookRail extends ConsumerWidget {
  const BookRail({
    super.key,
    required this.title,
    this.subtitle,
    required this.sectionProvider,
    required this.emptyMessage,
    this.badgeLabel,
    this.basePath = '/home',
    this.useFeatureCard = false,
  });

  final String title;
  final String? subtitle;
  final ProviderListenable<AsyncValue<List<Book>>> sectionProvider;
  final String emptyMessage;
  final String? badgeLabel;
  final String basePath;

  /// basis.png's "For You" rail uses wide landscape artwork cards instead
  /// of the standard portrait cover card.
  final bool useFeatureCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(sectionProvider);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, subtitle: subtitle),
          // Sized with headroom above BookCard/FeatureBookCard's actual
          // content height (cover + title + author + rating/price), not
          // just the cover's aspect ratio — the tighter values here used
          // to overflow once real book data (title/author text) rendered.
          SizedBox(
            height: useFeatureCard ? 232 : 300,
            child: booksAsync.when(
              data: (books) {
                if (books.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        emptyMessage,
                        style: TextStyle(color: context.colors.textTertiary, fontSize: 13),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final book = books[i];
                    if (useFeatureCard) {
                      return FeatureBookCard(
                        book: book,
                        onTap: () => context.push('$basePath/book/${book.id}'),
                      );
                    }
                    return BookCard(
                      book: book,
                      badgeLabel: badgeLabel,
                      onTap: () => context.push('$basePath/book/${book.id}'),
                    );
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.ink),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Could not load "$title".',
                  style: TextStyle(color: context.colors.error, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
