import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_color_tokens.dart';

/// Avatar with the small circular camera badge from profile_basis.png.
/// Pass [onEditTap] to make the badge tappable (Edit Profile); omit it to
/// render a plain read-only avatar (My Profile header).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    this.newBytes,
    this.radius = 42,
    this.onEditTap,
  });

  final String? photoUrl;
  final Uint8List? newBytes;
  final double radius;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = radius * 2;

    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: _content(context),
            ),
          ),
          if (onEditTap != null)
            Positioned(
              right: -6,
              bottom: -6,
              child: Semantics(
                button: true,
                label: 'Change profile photo',
                child: InkWell(
                  onTap: onEditTap,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.ink,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(BorderSide(color: colors.authBackground, width: 2)),
                      ),
                      child: Icon(Icons.camera_alt_rounded, size: 15, color: colors.onInk),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    // A just-picked local image always wins over whatever's already saved,
    // so the preview updates the instant you pick a new photo.
    if (newBytes != null) {
      return Image.memory(
        newBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallback(context),
      );
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return Image.network(
        photoUrl!,
        fit: BoxFit.cover,
        // A broken/unreachable URL used to render as a blank circle with
        // CircleAvatar.backgroundImage (no visible signal anything went
        // wrong) — this falls back to the person icon instead.
        errorBuilder: (context, error, stackTrace) => _fallback(context),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: context.colors.surfaceMuted,
            alignment: Alignment.center,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.textTertiary),
            ),
          );
        },
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: context.colors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded, size: radius * 0.9, color: context.colors.textTertiary),
    );
  }
}
