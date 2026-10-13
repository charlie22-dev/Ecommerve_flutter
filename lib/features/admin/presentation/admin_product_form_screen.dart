import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/models/book.dart';
import '../../../core/services/db.dart' show errorMessage;
import '../../../core/services/image_storage.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/book_cover_image.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../seller/presentation/seller_providers.dart';
import 'admin_product_controller.dart';
import 'admin_products_screen.dart' show confirmDeleteProduct;

/// Add/Edit Product, for admins and (with [sellerMode]) for sellers.
/// `bookId` null means "create"; non-null means "edit that book".
class AdminProductFormScreen extends ConsumerStatefulWidget {
  const AdminProductFormScreen({super.key, this.bookId, this.sellerMode = false});

  final String? bookId;

  /// Seller Center: no Home-page rails or delete, covers go in the store's
  /// folder, and saving submits for admin review instead of publishing.
  final bool sellerMode;

  @override
  ConsumerState<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends ConsumerState<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _publisher = TextEditingController();
  final _language = TextEditingController(text: 'English');
  final _pages = TextEditingController();
  final _isbn = TextEditingController();

  BookType _type = BookType.book;
  BookFormat _format = BookFormat.paperback;
  final Set<String> _genres = {};
  final Set<FeaturedSection> _sections = {};
  DateTime? _releaseDate;

  // Not editable here, but carried through so saving doesn't wipe them.
  List<String> _tags = const [];
  int? _totalChapters;

  Uint8List? _newCoverBytes;
  String? _newCoverExtension;
  String _existingCoverUrl = '';
  double _existingRating = 0;
  int _existingRatingCount = 0;
  late String _listingStatus = widget.sellerMode ? 'pending_review' : 'published';
  String? _moderationNote;

  bool _prefilled = false;

  bool get _isEditing => widget.bookId != null;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    _publisher.dispose();
    _language.dispose();
    _pages.dispose();
    _isbn.dispose();
    super.dispose();
  }

  void _prefillFrom(Book book) {
    if (_prefilled) return;
    _prefilled = true;
    _title.text = book.title;
    _author.text = book.author;
    _description.text = book.description;
    _price.text = book.price == 0 ? '' : book.price.toStringAsFixed(2);
    _stock.text = '${book.stock}';
    _publisher.text = book.publisher;
    _language.text = book.language;
    _pages.text = book.pages?.toString() ?? '';
    _isbn.text = book.isbn ?? '';
    _type = book.type;
    _format = book.format;
    _genres
      ..clear()
      ..addAll(book.genres);
    _sections
      ..clear()
      ..addAll(book.featuredSections);
    _tags = book.tags;
    _totalChapters = book.totalChapters;
    _releaseDate = book.releaseDate;
    _existingCoverUrl = book.coverUrl;
    _existingRating = book.rating;
    _existingRatingCount = book.ratingCount;
    _listingStatus = book.listingStatus;
    _moderationNote = book.moderationNote;
  }

  Future<void> _pickCover() async {
    // Covers render at most ~340px wide; a raw phone photo is several MB.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1500,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = ImageStorage.extensionFor(picked);
    setState(() {
      _newCoverBytes = bytes;
      _newCoverExtension = ext;
    });
  }

  Future<void> _pickReleaseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _releaseDate = picked);
  }

  /// [status] overrides the listing status (a seller's "Save as Draft").
  Future<void> _submit({String? status}) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final draft = Book(
      id: widget.bookId ?? '',
      title: _title.text.trim(),
      author: _author.text.trim(),
      coverUrl: _existingCoverUrl,
      price: double.tryParse(_price.text.trim()) ?? 0,
      stock: int.tryParse(_stock.text.trim()) ?? 0,
      type: _type,
      genres: _genres.toList(),
      format: _format,
      language: _language.text.trim().isEmpty ? 'English' : _language.text.trim(),
      publisher: _publisher.text.trim(),
      pages: int.tryParse(_pages.text.trim()),
      isbn: _isbn.text.trim().isEmpty ? null : _isbn.text.trim(),
      rating: _existingRating,
      ratingCount: _existingRatingCount,
      releaseDate: _releaseDate,
      description: _description.text.trim(),
      featuredSections: _sections.toList(),
      tags: _tags,
      totalChapters: _totalChapters,
      listingStatus: status ?? _sellerSubmitStatus ?? _listingStatus,
    );

    final ok = await ref.read(adminProductControllerProvider.notifier).save(
          draft: draft,
          newCoverBytes: _newCoverBytes,
          newCoverExtension: _newCoverExtension,
          coverFolder: widget.sellerMode ? ref.read(myStoreProvider).value?.id : null,
        );

    if (!mounted) return;
    if (ok) {
      final message = !widget.sellerMode
          ? (_isEditing ? 'Product updated' : 'Product added')
          : draft.listingStatus == 'pending_review'
              ? "Sent for review — you'll be notified when it's approved"
              : 'Listing saved';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      context.pop();
    } else {
      final error = ref.read(adminProductControllerProvider).error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: ${errorMessage(error ?? 'unknown error')}')));
    }
  }

  /// Sellers keep a live listing live when editing; anything else goes
  /// (back) to admin review. Admins keep whatever status it has.
  String? get _sellerSubmitStatus {
    if (!widget.sellerMode) return null;
    return _listingStatus == 'published' ? 'published' : 'pending_review';
  }

  Widget _statusBanner() {
    final colors = context.colors;
    final (label, color) = listingStatusStyle(_listingStatus, colors);
    final hint = switch (_listingStatus) {
      'published' => 'Live in the store. Edits go live right away.',
      'pending_review' => 'Waiting for an admin to approve it.',
      'draft' => "Only you can see this. Submit it when it's ready.",
      'rejected' => 'Fix the issue below and submit again.',
      'suspended' => 'Hidden from the store by an admin.',
      _ => '',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(label: label, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(hint, style: TextStyle(color: colors.textSecondary, fontSize: 12))),
            ],
          ),
          if (_moderationNote != null && (_listingStatus == 'rejected' || _listingStatus == 'suspended')) ...[
            const SizedBox(height: 8),
            Text('Admin: $_moderationNote', style: TextStyle(color: colors.error, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await confirmDeleteProduct(context, _title.text);
    if (!confirmed || !mounted) return;

    final ok = await ref.read(adminProductControllerProvider.notifier).delete(
          Book(id: widget.bookId!, title: _title.text, author: _author.text, coverUrl: _existingCoverUrl),
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(adminProductControllerProvider).isLoading;

    if (_isEditing && !_prefilled) {
      final bookAsync = ref.watch(bookByIdProvider(widget.bookId!));
      return Scaffold(
        appBar: AppBar(title: Text(widget.sellerMode ? 'Edit Listing' : 'Edit Product')),
        body: bookAsync.when(
          data: (book) {
            if (book == null) {
              return const Center(child: Text('Product not found'));
            }
            _prefillFrom(book);
            return _buildForm(isSaving);
          },
          loading: () => Center(child: CircularProgressIndicator(color: context.colors.ink)),
          error: (err, _) => const Center(child: Text('Could not load this product.')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sellerMode
            ? (_isEditing ? 'Edit Listing' : 'New Listing')
            : (_isEditing ? 'Edit Product' : 'Add Product')),
        actions: _isEditing && !widget.sellerMode
            ? [
                IconButton(
                  tooltip: 'Delete product',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: isSaving ? null : _confirmDelete,
                ),
              ]
            : null,
      ),
      body: _buildForm(isSaving),
    );
  }

  Widget _buildForm(bool isSaving) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.sellerMode && _isEditing) _statusBanner(),
            Center(child: _CoverPicker(
              existingUrl: _existingCoverUrl,
              newBytes: _newCoverBytes,
              onTap: _pickCover,
            )),
            const SizedBox(height: 24),
            const _FieldLabel('Title *'),
            TextFormField(
              controller: _title,
              style: TextStyle(color: context.colors.textPrimary),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Author *'),
            TextFormField(
              controller: _author,
              style: TextStyle(color: context.colors.textPrimary),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Author is required' : null,
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Description'),
            TextFormField(
              controller: _description,
              maxLines: 4,
              style: TextStyle(color: context.colors.textPrimary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Price *'),
                      TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: context.colors.textPrimary),
                        decoration: const InputDecoration(prefixText: '₱ '),
                        validator: (v) {
                          final value = double.tryParse((v ?? '').trim());
                          if (value == null || value <= 0) return 'Enter a valid price';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Stock'),
                      TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: context.colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Type'),
            _Dropdown<BookType>(
              value: _type,
              items: BookType.values,
              labelOf: (t) => t.label,
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Genre'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kGenreOptions.map((genre) {
                final selected = _genres.contains(genre);
                return FilterChip(
                  label: Text(genre),
                  selected: selected,
                  onSelected: (value) => setState(() {
                    if (value) {
                      _genres.add(genre);
                    } else {
                      _genres.remove(genre);
                    }
                  }),
                  selectedColor: context.colors.ink,
                  labelStyle: TextStyle(color: selected ? context.colors.onInk : context.colors.textPrimary, fontWeight: FontWeight.w600),
                  backgroundColor: context.colors.surface,
                  side: BorderSide(color: selected ? context.colors.ink : context.colors.border),
                  shape: const StadiumBorder(),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (!widget.sellerMode) ...[
              const _FieldLabel('Show on Home page'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                // `nowReading` isn't a store rail (Home's "Now Reading" card comes
                // from the user's own library), so it isn't offered here.
                children: FeaturedSection.values.where((s) => s != FeaturedSection.nowReading).map((section) {
                  final selected = _sections.contains(section);
                  return FilterChip(
                    label: Text(_sectionLabel(section)),
                    selected: selected,
                    onSelected: (value) => setState(() {
                      if (value) {
                        _sections.add(section);
                      } else {
                        _sections.remove(section);
                      }
                    }),
                    selectedColor: context.colors.ink,
                    labelStyle: TextStyle(color: selected ? context.colors.onInk : context.colors.textPrimary, fontWeight: FontWeight.w600),
                    backgroundColor: context.colors.surface,
                    side: BorderSide(color: selected ? context.colors.ink : context.colors.border),
                    shape: const StadiumBorder(),
                  );
                }).toList(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Pick none to list it only in the Store.',
                  style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const _FieldLabel('Format'),
            _Dropdown<BookFormat>(
              value: _format,
              items: BookFormat.values,
              labelOf: (f) => f.label,
              onChanged: (v) => setState(() => _format = v),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Language'),
            TextFormField(controller: _language, style: TextStyle(color: context.colors.textPrimary)),
            const SizedBox(height: 16),
            const _FieldLabel('Publisher'),
            TextFormField(controller: _publisher, style: TextStyle(color: context.colors.textPrimary)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Pages'),
                      TextFormField(
                        controller: _pages,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: context.colors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('ISBN'),
                      TextFormField(controller: _isbn, style: TextStyle(color: context.colors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Rating'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: context.colors.star, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _existingRatingCount == 0
                        ? 'No reviews yet'
                        : '${_existingRating.toStringAsFixed(1)} ($_existingRatingCount reviews)',
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                  const Spacer(),
                  Text('Read-only', style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Release date'),
            InkWell(
              onTap: _pickReleaseDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 18, color: context.colors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      _releaseDate == null ? 'Select a date' : DateFormat.yMMMd().format(_releaseDate!),
                      style: TextStyle(color: _releaseDate == null ? context.colors.textTertiary : context.colors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (!widget.sellerMode)
              PrimaryButton(
                label: _isEditing ? 'Save Changes' : 'Add Product',
                isLoading: isSaving,
                onPressed: _submit,
              )
            else ...[
              PrimaryButton(
                label: _listingStatus == 'published' ? 'Save Changes' : 'Submit for Review',
                isLoading: isSaving,
                onPressed: _submit,
              ),
              if (_listingStatus != 'published') ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: isSaving ? null : () => _submit(status: 'draft'),
                  child: const Text('Save as Draft'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

String _sectionLabel(FeaturedSection s) => switch (s) {
      FeaturedSection.nowReading => 'Now Reading',
      FeaturedSection.forYou => 'For You',
      FeaturedSection.trending => 'Trending',
      FeaturedSection.newReleases => 'New Releases',
    };

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.value, required this.items, required this.labelOf, required this.onChanged});

  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textSecondary),
          style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
          dropdownColor: context.colors.surface,
          items: items
              .map((item) => DropdownMenuItem<T>(value: item, child: Text(labelOf(item))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({required this.existingUrl, required this.newBytes, required this.onTap});

  final String existingUrl;
  final Uint8List? newBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Choose cover image',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 140,
          height: 200,
          decoration: BoxDecoration(
            color: context.colors.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: newBytes != null
              ? Image.memory(newBytes!, fit: BoxFit.cover)
              : existingUrl.isNotEmpty
                  ? BookCoverImage(url: existingUrl, borderRadius: 0)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: context.colors.textTertiary, size: 32),
                        SizedBox(height: 8),
                        Text('Add cover', style: TextStyle(color: context.colors.textTertiary, fontSize: 12)),
                      ],
                    ),
        ),
      ),
    );
  }
}
