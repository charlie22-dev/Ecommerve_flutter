import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/image_storage.dart';

/// Uploads a review's optional photo to the `review-photos` bucket and
/// returns its public URL. The `<uid>_` file-name prefix is what the
/// storage policy checks.
class ReviewPhotoUploader {
  Future<String> upload({
    required String uid,
    required String orderId,
    required Uint8List bytes,
    required String fileExtension,
  }) {
    return ImageStorage.upload(
      bucket: 'review-photos',
      path: '${uid}_${orderId}_${const Uuid().v4()}.$fileExtension',
      bytes: bytes,
      fileExtension: fileExtension,
    );
  }
}

final reviewPhotoUploaderProvider = Provider((ref) => ReviewPhotoUploader());
