import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/cart_line.dart';
import 'cart_providers.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../checkout/presentation/checkout_providers.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _editMode = false;

  Set<String> _getEffectiveSelection(List<CartLine> lines, Set<String>? saved) {
    if (saved != null) return saved;
    // Default selection: all available in-stock items
    return lines.where((l) => l.book.inStock && l.book.stock > 0).map((l) => l.book.id).toSet();
  }

  void _toggleAll(List<CartLine> lines, Set<String> current) {
    final available = lines.where((l) => l.book.inStock && l.book.stock > 0).map((l) => l.book.id).toSet();
    final isAllSelected = available.isNotEmpty && available.every(current.contains);
    final next = isAllSelected ? <String>{} : available;
    ref.read(selectedCartBookIdsProvider.notifier).state = next;
  }

  void _toggleItem(String bookId, List<CartLine> lines) {
    // Start with current selection, or all in-stock items if not modified yet
    final current = ref.read(selectedCartBookIdsProvider) ?? _getEffectiveSelection(lines, null);
    final next = {...current};
    if (next.contains(bookId)) {
      next.remove(bookId);
    } else {
      next.add(bookId);
    }
    ref.read(selectedCartBookIdsProvider.notifier).state = next;
  }

  Future<void> _deleteSelected(List<CartLine> lines, Set<String> selected) async {
    final toDelete = lines.where((l) => selected.contains(l.book.id)).map((l) => l.book.id).toList();
    if (toDelete.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete items?'),
        content: Text('Remove ${toDelete.length} item${toDelete.length == 1 ? '' : 's'} from your cart?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: ctx.colors.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(cartActionsProvider).removeMany(toDelete);
      ref.read(selectedCartBookIdsProvider.notifier).state = null;
      setState(() => _editMode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linesAsync = ref.watch(cartLinesProvider);
    final lines = linesAsync.value;
    final selectedIds = ref.watch(selectedCartBookIdsProvider);

    final effectiveSelection = lines == null ? <String>{} : _getEffectiveSelection(lines, selectedIds);
    final selectedLines = lines?.where((l) => effectiveSelection.contains(l.book.id)).toList() ?? [];
    final selectedTotal = selectedLines.fold<double>(0, (sum, l) => sum + l.lineTotal);
    final selectedCount = selectedLines.fold<int>(0, (sum, l) => sum + l.quantity);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoute.home);
            }
          },
        ),
        title: Text(lines == null ? 'Cart' : 'Cart (${lines.length})'),
        actions: [
          // Messages icon
          IconButton(
            tooltip: 'Messages',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => context.push(AppRoute.messages),
          ),
          // Edit / Done button
          if (lines != null && lines.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _editMode = !_editMode),
              child: Text(
                _editMode ? 'Done' : 'Edit',
                style: TextStyle(color: context.colors.ink, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: lines != null
          ? (lines.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Your cart is empty',
                  message: 'Browse the catalog and add a few titles.',
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: lines.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          if (i == lines.length) return const _SeeAllVouchersRow();
                          final line = lines[i];
                          final isSelected = effectiveSelection.contains(line.book.id);
                          final canSelect = line.book.inStock && line.book.stock > 0;
                          return _CartLineTile(
                            key: ValueKey(line.book.id),
                            line: line,
                            isSelected: isSelected,
                            editMode: _editMode,
                            onToggle: canSelect ? () => _toggleItem(line.book.id, lines) : null,
                          );
                        },
                      ),
                    ),
                    _CartBottomBar(
                      lines: lines,
                      effectiveSelection: effectiveSelection,
                      selectedCount: selectedCount,
                      selectedTotal: selectedTotal,
                      editMode: _editMode,
                      onToggleAll: () => _toggleAll(lines, effectiveSelection),
                      onDeleteSelected: () => _deleteSelected(lines, effectiveSelection),
                    ),
                  ],
                ))
          : (linesAsync.isLoading
              ? Center(child: CircularProgressIndicator(color: context.colors.ink))
              : Center(child: Text('Could not load your cart.', style: TextStyle(color: context.colors.error)))),
    );
  }
}

class _CartLineTile extends ConsumerStatefulWidget {
  const _CartLineTile({
    super.key,
    required this.line,
    required this.isSelected,
    required this.editMode,
    this.onToggle,
  });
  final CartLine line;
  final bool isSelected;
  final bool editMode;
  final VoidCallback? onToggle;

  @override
  ConsumerState<_CartLineTile> createState() => _CartLineTileState();
}

class _CartLineTileState extends ConsumerState<_CartLineTile> {
  int? _optimisticQty;
  bool _editingQty = false;
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: '${widget.line.quantity}');
  }

  @override
  void didUpdateWidget(covariant _CartLineTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.quantity != widget.line.quantity) {
      _optimisticQty = null;
      if (!_editingQty) {
        _qtyController.text = '${widget.line.quantity}';
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  int get _displayQty => _optimisticQty ?? widget.line.quantity;

  void _setQty(int newQty) {
    if (newQty < 1) return;
    final maxStock = widget.line.book.stock;
    final clampedQty = maxStock > 0 && newQty > maxStock ? maxStock : newQty;
    setState(() => _optimisticQty = clampedQty);
    ref.read(cartActionsProvider).setQuantity(widget.line.book.id, clampedQty);
  }

  void _commitTypedQty() {
    setState(() => _editingQty = false);
    final parsed = int.tryParse(_qtyController.text.trim());
    if (parsed != null && parsed >= 1) {
      final maxStock = widget.line.book.stock;
      final clamped = maxStock > 0 && parsed > maxStock ? maxStock : parsed;
      _qtyController.text = '$clamped';
      _setQty(clamped);
    } else {
      _qtyController.text = '$_displayQty';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final book = widget.line.book;
    final storeName = book.storeId != null
        ? ref.watch(storeByIdProvider(book.storeId!)).value?.name ?? 'BookVerse Official'
        : 'BookVerse Official';
    final isOutOfStock = !book.inStock || book.stock <= 0;
    final isAtMaxStock = book.stock > 0 && _displayQty >= book.stock;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOutOfStock ? colors.surfaceMuted : colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.isSelected && !isOutOfStock ? colors.ink : colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seller header
          Row(
            children: [
              Icon(Icons.storefront_rounded, size: 13, color: colors.ink),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Product row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              GestureDetector(
                onTap: isOutOfStock ? null : widget.onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 16, right: 10),
                  decoration: BoxDecoration(
                    color: widget.isSelected && !isOutOfStock ? colors.ink : Colors.transparent,
                    border: Border.all(
                      color: isOutOfStock ? colors.textTertiary : (widget.isSelected ? colors.ink : colors.border),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: widget.isSelected && !isOutOfStock
                      ? Icon(Icons.check_rounded, size: 14, color: colors.onInk)
                      : null,
                ),
              ),

              // Cover
              SizedBox(
                width: 60,
                height: 88,
                child: Stack(
                  children: [
                    BookCoverImage(url: book.coverUrl),
                    if (isOutOfStock)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: const Text('Out of\nstock', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: widget.editMode ? colors.error : colors.textTertiary,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remove item?'),
                                content: Text('Remove "${book.title}" from your cart?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: Text('Remove', style: TextStyle(color: ctx.colors.error)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && mounted) {
                              await ref.read(cartActionsProvider).remove(book.id);
                              final current = ref.read(selectedCartBookIdsProvider);
                              if (current != null && current.contains(book.id)) {
                                ref.read(selectedCartBookIdsProvider.notifier).state = {...current}..remove(book.id);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${book.price.toStringAsFixed(0)}',
                      style: TextStyle(color: colors.ink, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 8),

                    // Quantity row
                    Row(
                      children: [
                        _QtyButton(
                          icon: Icons.remove_rounded,
                          enabled: _displayQty > 1 && !isOutOfStock,
                          onTap: () => _setQty(_displayQty - 1),
                        ),

                        // Tappable qty display that converts to text field
                        GestureDetector(
                          onTap: isOutOfStock
                              ? null
                              : () {
                                  setState(() {
                                    _editingQty = true;
                                    _qtyController.text = '$_displayQty';
                                  });
                                },
                          child: Container(
                            width: 48,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: _editingQty ? colors.ink : colors.border),
                              borderRadius: BorderRadius.circular(6),
                              color: _editingQty ? colors.surface : colors.background,
                            ),
                            child: _editingQty
                                ? TextField(
                                    controller: _qtyController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    autofocus: true,
                                    style: TextStyle(fontSize: 13, color: colors.textPrimary, fontWeight: FontWeight.w700),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (_) => _commitTypedQty(),
                                    onEditingComplete: _commitTypedQty,
                                    onTapOutside: (_) => _commitTypedQty(),
                                  )
                                : Text('$_displayQty', style: TextStyle(fontSize: 13, color: colors.textPrimary, fontWeight: FontWeight.w700)),
                          ),
                        ),

                        _QtyButton(
                          icon: Icons.add_rounded,
                          enabled: !isOutOfStock && !isAtMaxStock,
                          onTap: () => _setQty(_displayQty + 1),
                        ),
                      ],
                    ),

                    // Stock feedback notes
                    if (isOutOfStock)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          'Out of stock',
                          style: TextStyle(color: colors.error, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      )
                    else if (isAtMaxStock)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          'Max available stock reached (${book.stock})',
                          style: TextStyle(color: colors.accentOrange, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      )
                    else if (book.stock <= 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          'Only ${book.stock} pieces left',
                          style: TextStyle(color: colors.accentOrange, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap, this.enabled = true});
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? context.colors.border : context.colors.borderSubtle),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: enabled ? context.colors.textPrimary : context.colors.textTertiary),
      ),
    );
  }
}

class _SeeAllVouchersRow extends StatelessWidget {
  const _SeeAllVouchersRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.go(AppRoute.vouchers),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer_outlined, color: colors.ink, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('See all vouchers', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _CartBottomBar extends ConsumerWidget {
  const _CartBottomBar({
    required this.lines,
    required this.effectiveSelection,
    required this.selectedCount,
    required this.selectedTotal,
    required this.editMode,
    required this.onToggleAll,
    required this.onDeleteSelected,
  });

  final List<CartLine> lines;
  final Set<String> effectiveSelection;
  final int selectedCount;
  final double selectedTotal;
  final bool editMode;
  final VoidCallback onToggleAll;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final availableLines = lines.where((l) => l.book.inStock && l.book.stock > 0).toList();
    final allSelected = availableLines.isNotEmpty && availableLines.every((l) => effectiveSelection.contains(l.book.id));
    final hasSelection = lines.any((line) => effectiveSelection.contains(line.book.id));

    // Validate that no out-of-stock item is selected for checkout
    final selectedLines = lines.where((l) => effectiveSelection.contains(l.book.id)).toList();
    final hasOutOfStockSelected = selectedLines.any((l) => !l.book.inStock || l.book.stock <= 0 || l.quantity > l.book.stock);
    final canCheckout = hasSelection && !hasOutOfStockSelected;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            // Select All checkbox
            GestureDetector(
              onTap: onToggleAll,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: allSelected ? colors.ink : Colors.transparent,
                      border: Border.all(color: allSelected ? colors.ink : colors.border, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: allSelected ? Icon(Icons.check_rounded, size: 14, color: colors.onInk) : null,
                  ),
                  const SizedBox(width: 6),
                  Text('All', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),

            const Spacer(),

            if (editMode) ...[
              // Delete selected in edit mode
              TextButton.icon(
                onPressed: hasSelection ? onDeleteSelected : null,
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: hasSelection ? colors.error : colors.textTertiary),
                label: Text(
                  'Delete (${effectiveSelection.length})',
                  style: TextStyle(color: hasSelection ? colors.error : colors.textTertiary, fontWeight: FontWeight.w700),
                ),
              ),
            ] else ...[
              // Total and checkout
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasOutOfStockSelected
                        ? 'Contains out of stock'
                        : 'Total ($selectedCount item${selectedCount != 1 ? 's' : ''})',
                    style: TextStyle(
                      color: hasOutOfStockSelected ? colors.error : colors.textSecondary,
                      fontSize: 11,
                      fontWeight: hasOutOfStockSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    '₱${selectedTotal.toStringAsFixed(2)}',
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: PrimaryButton(
                  label: hasOutOfStockSelected ? 'Out of stock' : 'Checkout',
                  onPressed: canCheckout
                      ? () {
                          ref.read(buyNowItemProvider.notifier).state = null;
                          ref.read(selectedCartBookIdsProvider.notifier).state = {...effectiveSelection};
                          context.push('/checkout');
                        }
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
