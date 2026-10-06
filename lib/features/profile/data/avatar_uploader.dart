import 'dart:typed_data';

import '../../../core/services/image_storage.dart';

/// Uploads a picked avatar to the `avatars` bucket as `<uid>.<ext>` and
/// returns its public URL. Bytes rather than a File so this works on web too.
class AvatarUploader {
  Future<String> upload({
    required String uid,
    required Uint8List bytes,
    required String fileExtension,
  }) {
    return ImageStorage.upload(
      bucket: 'avatars',
      path: '$uid.$fileExtension',
      bytes: bytes,
      fileExtension: fileExtension,
    );
  }
}
