import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/book.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/admin_repository.dart';
import 'admin_product_controller.dart';
import 'admin_providers.dart';

/// Every product in the catalog, newest first — search, quick restock,
/// edit (tap) and delete.
class AdminProductsScreen extends ConsumerWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final productsAsync = ref.watch(adminProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoute.adminAddProduct),
        backgroundColor: colors.ink,
        foregroundColor: colors.onInk,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              onChanged: (v) => ref.read(adminProductSearchProvider.notifier).state = v,
              style: TextStyle(color: colors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search title, author or ISBN',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              data: (books) {
                if (books.isEmpty) {
                  return EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: ref.read(adminProductSearchProvider).isEmpty ? 'No products yet' : 'No matches',
                    message: 'Tap "Add Product" to create your first listing.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                  itemCount: books.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        '${books.length} product${books.length == 1 ? '' : 's'}',
                        style: TextStyle(color: colors.textTertiary, fontSize: 12),
                      );
                    }
                    return _ProductTile(book: books[i - 1]);
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
              error: (e, _) => Center(child: Text('Could not load products.\n$e', textAlign: TextAlign.center)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.book});
  final Book book;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDeleteProduct(context, book.title);
    if (!ok || !context.mounted) return;
    final deleted = await ref.read(adminProductControllerProvider.notifier).delete(book);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(deleted ? 'Deleted "${book.title}"' : 'Could not delete this product.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final low = book.stock <= AdminRepository.lowStockThreshold;
    final repo = ref.read(adminRepositoryProvider);

    return InkWell(
      onTap: () => context.push('${AppRoute.adminEditProduct}/${book.id}/edit'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            SizedBox(width: 48, height: 72, child: BookCoverImage(url: book.coverUrl, borderRadius: 8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${book.type.label} · ₱${book.price.toStringAsFixed(2)}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _StockButton(
                        icon: Icons.remove_rounded,
                        onTap: book.stock > 0 ? () => repo.setStock(book.id, book.stock - 1) : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          book.stock == 0 ? 'Out of stock' : '${book.stock} in stock',
                          style: TextStyle(
                            color: low ? colors.error : colors.textSecondary,
                            fontWeight: low ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      _StockButton(icon: Icons.add_rounded, onTap: () => repo.setStock(book.id, book.stock + 1)),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: colors.textTertiary),
              onSelected: (action) {
                if (action == 'edit') context.push('${AppRoute.adminEditProduct}/${book.id}/edit');
                if (action == 'delete') _delete(context, ref);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: colors.error))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StockButton extends StatelessWidget {
  const _StockButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.border)),
        child: Icon(icon, size: 16, color: onTap == null ? colors.textTertiary : colors.textPrimary),
      ),
    );
  }
}

/// Shared by the product list and the edit form.
Future<bool> confirmDeleteProduct(BuildContext context, String title) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this product?'),
      content: Text('"$title" and its cover image will be removed for everyone. This can\'t be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Delete', style: TextStyle(color: context.colors.error)),
        ),
      ],
    ),
  );
  return confirmed == true;
}
