import 'dart:typed_data';

import '../../../core/services/image_storage.dart';

/// Uploads a picked cover image to the `book-covers` bucket and returns its
/// URL. Admins write anywhere; sellers only inside a [folder] named after
/// their store id (storage policies in supabase/schema.sql).
class CoverImageUploader {
  Future<String> upload({
    required String bookId,
    String? folder,
    required Uint8List bytes,
    required String fileExtension,
  }) {
    return ImageStorage.upload(
      bucket: 'book-covers',
      path: folder == null ? '$bookId.$fileExtension' : '$folder/$bookId.$fileExtension',
      bytes: bytes,
      fileExtension: fileExtension,
    );
  }
}
