import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/book.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_card.dart';
import '../../../core/widgets/cart_icon_button.dart';
import '../../../core/widgets/section_header.dart';
import '../../library/presentation/library_providers.dart';
import '../../vouchers/presentation/widgets/voucher_popup.dart';
import 'catalog_providers.dart';
import 'widgets/book_rail.dart';
import 'widgets/now_reading_hero_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fires once per app session (see VoucherPopup.showIfNeeded) —
    // StatefulShellRoute keeps this branch's Home instance alive across
    // tab switches, so initState only runs once per cold start, not once
    // per visit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) VoucherPopup.showIfNeeded(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final nowReadingAsync = ref.watch(nowReadingProvider);
    final allBooksAsync = ref.watch(allBooksProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Search books, authors, genres',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.push(AppRoute.explore),
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: context.colors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, color: context.colors.textTertiary, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Search books, authors, genres…',
                                  style: TextStyle(color: context.colors.textTertiary, fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const CartIconButton(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: nowReadingAsync.when(
                data: (nowReading) {
                  if (nowReading == null) return const SizedBox.shrink();
                  return NowReadingHeroCard(nowReading: nowReading);
                },
                loading: () => SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.ink)),
                ),
                error: (err, _) => const SizedBox.shrink(),
              ),
            ),
            BookRail(
              title: 'For You',
              sectionProvider: sectionBooksProvider(FeaturedSection.forYou),
              emptyMessage: 'Recommendations will appear as you read more.',
              useFeatureCard: true,
            ),
            BookRail(
              title: 'Trending',
              sectionProvider: sectionBooksProvider(FeaturedSection.trending),
              badgeLabel: 'HOT',
              emptyMessage: 'No trending titles yet.',
            ),
            BookRail(
              title: 'New Releases',
              sectionProvider: sectionBooksProvider(FeaturedSection.newReleases),
              badgeLabel: 'NEW',
              emptyMessage: 'No new releases yet.',
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'All Books',
                onAction: () => context.go(AppRoute.store),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: allBooksAsync.when(
                data: (books) {
                  if (books.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No books in the catalog yet.',
                          style: TextStyle(color: context.colors.textTertiary, fontSize: 13),
                        ),
                      ),
                    );
                  }
                  return SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.44,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final Book book = books[i];
                        return BookCard(
                          book: book,
                          width: double.infinity,
                          showAddToCartButton: true,
                          onTap: () => context.push('/home/book/${book.id}'),
                        );
                      },
                      childCount: books.length,
                    ),
                  );
                },
                loading: () => SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.ink)),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('Could not load the catalog.', style: TextStyle(color: context.colors.error)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
