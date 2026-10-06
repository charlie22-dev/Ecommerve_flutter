import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/image_storage.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_providers.dart';
import 'profile_edit_controller.dart';
import 'widgets/profile_avatar.dart';

/// Matches profile_basis.png's Edit Profile layout structurally (avatar +
/// camera badge, labeled rounded fields, checkmark save action) — scoped
/// to fields BookVerse actually has: display name and avatar. Email is
/// auth-owned and shown read-only; there's no username/phone
/// field in this app's data model, so those rows from the reference are
/// intentionally left out rather than faked.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  Uint8List? _newAvatarBytes;
  String? _newAvatarExtension;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      // Downscale at pick time: an avatar renders at ~104px, but a raw
      // phone photo is 3-12 MB, which made the upload crawl (imageQuality
      // alone re-encodes without resizing).
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = ImageStorage.extensionFor(picked);
      setState(() {
        _newAvatarBytes = bytes;
        _newAvatarExtension = ext;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the photo picker: $e'), backgroundColor: context.colors.error),
      );
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a name.')));
      return;
    }
    final ok = await ref.read(profileEditControllerProvider.notifier).save(
          displayName: _name.text.trim(),
          newAvatarBytes: _newAvatarBytes,
          newAvatarExtension: _newAvatarExtension,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      context.pop();
    }
  }

  Future<void> _changePassword() async {
    final email = ref.read(appUserProvider).value?.email;
    if (email == null || email.isEmpty) return;
    final ok = await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Password reset email sent to $email' : 'Could not send reset email.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).value;
    final isSaving = ref.watch(profileEditControllerProvider).isLoading;

    ref.listen(profileEditControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString()), backgroundColor: context.colors.error),
        );
      }
    });

    if (!_initialized && appUser != null) {
      _initialized = true;
      _name.text = appUser.displayName;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          Semantics(
            button: true,
            label: 'Save profile',
            child: IconButton(
              icon: isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.ink),
                    )
                  : const Icon(Icons.check_rounded),
              onPressed: isSaving ? null : _save,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ProfileAvatar(
                photoUrl: appUser?.photoUrl,
                newBytes: _newAvatarBytes,
                radius: 52,
                onEditTap: _pickAvatar,
              ),
            ),
            const SizedBox(height: 28),
            const _FieldLabel('Name'),
            TextField(controller: _name, style: TextStyle(color: context.colors.textPrimary)),
            const SizedBox(height: 16),
            const _FieldLabel('Email address'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(appUser?.email ?? '', style: TextStyle(color: context.colors.textSecondary)),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Password'),
            InkWell(
              onTap: _changePassword,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('••••••••••••', style: TextStyle(color: context.colors.textSecondary, letterSpacing: 2)),
                    ),
                    Text('Send reset email', style: TextStyle(color: context.colors.ink, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
