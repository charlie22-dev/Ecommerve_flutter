import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/book.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/admin_repository.dart';
import 'admin_product_controller.dart';
import 'admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/admin_table.dart';

/// Every product in the catalog, newest first — search, quick restock,
/// edit (tap) and delete.
class AdminProductsScreen extends ConsumerWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final productsAsync = ref.watch(adminProductsProvider);
    final wide = AdminShell.isWide(context);
    final pad = wide ? 28.0 : 20.0;

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
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 8),
            child: AdminSearchField(
              hint: 'Search title, author or ISBN',
              onChanged: (v) => ref.read(adminProductSearchProvider.notifier).state = v,
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
                if (wide) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(pad, 4, pad, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${books.length} product${books.length == 1 ? '' : 's'}',
                          style: TextStyle(color: colors.textTertiary, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        _ProductsTable(books: books),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(pad, 4, pad, 96),
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

Future<void> _deleteProduct(BuildContext context, WidgetRef ref, Book book) async {
  final ok = await confirmDeleteProduct(context, book.title);
  if (!ok || !context.mounted) return;
  final deleted = await ref.read(adminProductControllerProvider.notifier).delete(book);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(deleted ? 'Deleted "${book.title}"' : 'Could not delete this product.')));
}

/// Out of stock = error, low = orange, otherwise normal text.
Color _stockColor(Book book, AppColorTokens colors) => book.stock == 0
    ? colors.error
    : book.stock <= AdminRepository.lowStockThreshold
    ? colors.accentOrange
    : colors.textSecondary;

class _ProductsTable extends ConsumerWidget {
  const _ProductsTable({required this.books});
  final List<Book> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final repo = ref.read(adminRepositoryProvider);
    return AdminTable(
      columns: const [
        DataColumn(label: Text('PRODUCT')),
        DataColumn(label: Text('TYPE')),
        DataColumn(label: Text('PRICE'), numeric: true),
        DataColumn(label: Text('STOCK')),
        DataColumn(label: Text('STATUS')),
        DataColumn(label: Text('ACTIONS')),
      ],
      rows: [
        for (final book in books)
          () {
            final (label, color) = listingStatusStyle(book.listingStatus, colors);
            void edit() => context.push('${AppRoute.adminEditProduct}/${book.id}/edit');
            return adminRow(
              context,
              onTap: edit,
              cells: [
                DataCell(
                  TwoLineCell(
                    book.title,
                    book.author,
                    leading: SizedBox(
                      width: 32,
                      height: 48,
                      child: BookCoverImage(url: book.coverUrl, borderRadius: 6),
                    ),
                  ),
                ),
                DataCell(Text(book.type.label)),
                DataCell(
                  Text('₱${book.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StockButton(
                        icon: Icons.remove_rounded,
                        onTap: book.stock > 0 ? () => repo.setStock(book.id, book.stock - 1) : null,
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${book.stock}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _stockColor(book, colors), fontWeight: FontWeight.w800),
                        ),
                      ),
                      _StockButton(icon: Icons.add_rounded, onTap: () => repo.setStock(book.id, book.stock + 1)),
                    ],
                  ),
                ),
                DataCell(StatusChip(label: label, color: color)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: edit,
                        icon: Icon(Icons.edit_outlined, size: 20, color: colors.textPrimary),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => _deleteProduct(context, ref, book),
                        icon: Icon(Icons.delete_outline_rounded, size: 20, color: colors.error),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }(),
      ],
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
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
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            book.stock == 0 ? 'Out of stock' : '${book.stock} in stock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _stockColor(book, colors),
                              fontWeight: book.stock <= AdminRepository.lowStockThreshold
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 12,
                            ),
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
                if (action == 'delete') _deleteProduct(context, ref, book);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: colors.error)),
                ),
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.border),
        ),
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
