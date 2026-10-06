import 'dart:typed_data';

import '../../../core/services/image_storage.dart';

/// Uploads a picked cover image to the `book-covers` bucket (admin-only —
/// see the storage policies in supabase/schema.sql) and returns its URL.
class CoverImageUploader {
  Future<String> upload({
    required String bookId,
    required Uint8List bytes,
    required String fileExtension,
  }) {
    return ImageStorage.upload(
      bucket: 'book-covers',
      path: '$bookId.$fileExtension',
      bytes: bytes,
      fileExtension: fileExtension,
    );
  }
}
