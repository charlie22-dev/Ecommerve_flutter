import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/book.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../data/cover_image_uploader.dart';
import 'admin_providers.dart';

final coverImageUploaderProvider = Provider((ref) => CoverImageUploader());

final adminProductControllerProvider =
    AsyncNotifierProvider<AdminProductController, void>(AdminProductController.new);

class AdminProductController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Uploads the cover (if a new one was picked) then creates/updates the
  /// book document. An empty `draft.id` means create.
  Future<bool> save({
    required Book draft,
    Uint8List? newCoverBytes,
    String? newCoverExtension,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      var book = draft;

      if (newCoverBytes != null && newCoverExtension != null) {
        // Save first (without the new cover) if this is a brand-new book,
        // so we have an id to namespace the uploaded file under.
        final bookId =
            book.id.isEmpty ? await ref.read(bookRepositoryProvider).save(book) : book.id;
        final url = await ref.read(coverImageUploaderProvider).upload(
              bookId: bookId,
              bytes: newCoverBytes,
              fileExtension: newCoverExtension,
            );
        book = book.copyWith(id: bookId, coverUrl: url);
      }

      final id = await ref.read(bookRepositoryProvider).save(book);
      // Book Details caches by id — make an edit show up immediately.
      ref.invalidate(bookByIdProvider(id));
    });

    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    return !result.hasError;
  }

  /// Removes the product and its uploaded cover image.
  Future<bool> delete(Book book) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(adminRepositoryProvider).deleteProduct(book));
    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    return !result.hasError;
  }
}
