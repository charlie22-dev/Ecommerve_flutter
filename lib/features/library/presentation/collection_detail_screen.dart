import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_card.dart';
import '../../../core/widgets/empty_state.dart';
import 'collection_providers.dart';
import '../../catalog/presentation/catalog_providers.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider).value ?? const [];
    final collection = collections.where((c) => c.id == collectionId).firstOrNull;

    if (collection == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Collection not found', style: TextStyle(color: context.colors.textSecondary))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.title),
        actions: [
          IconButton(
            tooltip: 'Delete collection',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              await ref.read(collectionActionsProvider).delete(collectionId);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      body: collection.bookIds.isEmpty
          ? const EmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'No books yet',
              message: 'Add books to this collection from any book\'s details page.',
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (collection.description.isNotEmpty) ...[
                    Text(collection.description, style: TextStyle(color: context.colors.textSecondary)),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.48,
                      ),
                      itemCount: collection.bookIds.length,
                      itemBuilder: (context, i) {
                        final bookId = collection.bookIds[i];
                        final bookAsync = ref.watch(bookByIdProvider(bookId));
                        return bookAsync.when(
                          data: (book) => book == null
                              ? const SizedBox.shrink()
                              : BookCard(
                                  book: book,
                                  width: double.infinity,
                                  onTap: () => context.push('/library/book/${book.id}'),
                                ),
                          loading: () => const SizedBox.shrink(),
                          error: (err, _) => const SizedBox.shrink(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
