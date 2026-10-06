import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/avatar_uploader.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository());
final avatarUploaderProvider = Provider((ref) => AvatarUploader());

final profileEditControllerProvider =
    AsyncNotifierProvider<ProfileEditController, void>(ProfileEditController.new);

class ProfileEditController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Uploads the new avatar (if any) and saves the display name as two
  /// separate steps — a failed image upload used to abort the whole save
  /// silently (including the name change) since both ran inside one
  /// `AsyncValue.guard`. Now the name always saves, and an avatar failure
  /// surfaces its own error instead of swallowing everything.
  Future<bool> save({
    required String displayName,
    Uint8List? newAvatarBytes,
    String? newAvatarExtension,
  }) async {
    state = const AsyncLoading();

    String? photoUrl;
    if (newAvatarBytes != null && newAvatarExtension != null) {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid != null) {
        final uploadResult = await AsyncValue.guard(
          () => ref.read(avatarUploaderProvider).upload(
                uid: uid,
                bytes: newAvatarBytes,
                fileExtension: newAvatarExtension,
              ),
        );
        if (uploadResult.hasError) {
          state = AsyncError(_uploadErrorMessage(uploadResult.error), StackTrace.current);
          return false;
        }
        photoUrl = uploadResult.value;
      }
    }

    final saveResult = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updateProfile(displayName: displayName, photoUrl: photoUrl),
    );
    state = saveResult.hasError ? AsyncError('Could not save your profile. Please try again.', StackTrace.current) : const AsyncData(null);
    return !saveResult.hasError;
  }

  Future<bool> deleteAccount() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(profileRepositoryProvider).deleteAccount());
    state = result.hasError ? AsyncError(_deleteErrorMessage(result.error), StackTrace.current) : const AsyncData(null);
    return !result.hasError;
  }

  String _deleteErrorMessage(Object? error) {
    if (error is PostgrestException && error.message.contains('not signed in')) {
      return 'Your session expired. Please sign out and sign back in before deleting your account.';
    }
    return 'Could not delete your account. Please try again.';
  }

  String _uploadErrorMessage(Object? error) {
    if (error is TimeoutException) {
      return 'Photo upload timed out. Check your connection and try again.';
    }
    if (error is StorageException) {
      final status = error.statusCode;
      if (status == '403' || status == '401' || error.message.toLowerCase().contains('row-level security')) {
        return "You don't have permission to upload a photo.";
      }
      if (status == '404' || error.message.toLowerCase().contains('bucket not found')) {
        return 'Photo uploads are unavailable right now. Your other changes were not saved — try again without a new photo.';
      }
      if (status == '413') return 'That photo is too large. Please pick a smaller image.';
      return 'Could not upload that photo (${error.message}). Please try a different image.';
    }
    return 'Could not upload that photo. Please try a different image.';
  }
}
