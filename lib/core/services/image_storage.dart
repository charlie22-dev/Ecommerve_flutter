import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'db.dart';

/// Shared upload path for the app's public image buckets (avatars,
/// book-covers, review-photos — created in supabase/schema.sql).
abstract final class ImageStorage {
  static const _timeout = Duration(seconds: 45);

  /// Prefers the picked file's MIME type — on web the picked name is often
  /// a blob id with no extension, and HEIC/odd extensions would otherwise
  /// be uploaded with a bogus `image/<ext>` content type.
  static String extensionFor(XFile picked) {
    final mime = picked.mimeType;
    if (mime == 'image/png') return 'png';
    if (mime == 'image/webp') return 'webp';
    if (mime == 'image/gif') return 'gif';
    if (mime != null && mime.startsWith('image/')) return 'jpg';
    final name = picked.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    return const {'png', 'webp', 'gif'}.contains(ext) ? ext : 'jpg';
  }

  static String contentTypeFor(String fileExtension) =>
      'image/${fileExtension == 'jpg' ? 'jpeg' : fileExtension}';

  /// Uploads (overwriting any existing file at [path]) and returns the
  /// public URL. A `?v=` timestamp is appended because re-uploading to the
  /// same path keeps the same URL, and Image.network would otherwise keep
  /// showing the cached old picture.
  static Future<String> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final storage = db.storage.from(bucket);
    await storage
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentTypeFor(fileExtension), upsert: true),
        )
        .timeout(_timeout);
    final url = storage.getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
