import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/book_collection.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/book_cover_image.dart';
import '../../../catalog/presentation/catalog_providers.dart';

/// main_basis.png's "Recently Saved" card: up to 3 overlapping covers, a
/// book-count badge, title, and short description.
///
/// The reference also shows a "3 Readers" badge — this app has no
/// multi-reader/collaboration feature yet, so that badge is intentionally
/// left out rather than showing a fabricated number.
class CollectionCard extends ConsumerWidget {
  const CollectionCard({super.key, required this.collection, required this.onTap});

  final BookCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewIds = collection.bookIds.take(3).toList();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 13, color: context.colors.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        '${collection.bookCount} book${collection.bookCount == 1 ? '' : 's'}',
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(collection.title, style: Theme.of(context).textTheme.titleMedium),
            if (collection.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                collection.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 14),
            if (previewIds.isEmpty)
              Text('No books yet', style: TextStyle(color: context.colors.textTertiary, fontSize: 12))
            else
              SizedBox(
                height: 76,
                child: Stack(
                  children: [
                    for (var i = 0; i < previewIds.length; i++)
                      Positioned(
                        left: i * 44.0,
                        child: _CoverPreview(bookId: previewIds[i]),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoverPreview extends ConsumerWidget {
  const _CoverPreview({required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookByIdProvider(bookId));
    return Container(
      width: 52,
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.surface, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: bookAsync.when(
        data: (book) => book == null ? Container(color: context.colors.surfaceMuted) : BookCoverImage(url: book.coverUrl, borderRadius: 0),
        loading: () => Container(color: context.colors.surfaceMuted),
        error: (err, _) => Container(color: context.colors.surfaceMuted),
      ),
    );
  }
}
