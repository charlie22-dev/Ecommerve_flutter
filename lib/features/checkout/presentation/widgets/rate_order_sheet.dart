import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/order.dart';
import '../../../../core/models/review.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../reviews/data/review_photo_uploader.dart';
import '../../../reviews/presentation/review_providers.dart';
import '../checkout_providers.dart';

/// Writes a real `Review` document per book in the order (same star rating
/// and text applied to each, since this is a single "rate this order"
/// action rather than a per-item flow) — closing the loop the old
/// stars-only dialog left open (it only ever flipped `order.rated`).
class RateOrderSheet extends ConsumerStatefulWidget {
  const RateOrderSheet({super.key, required this.order});
  final Order order;

  static Future<void> show(BuildContext context, Order order) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => RateOrderSheet(order: order),
    );
  }

  @override
  ConsumerState<RateOrderSheet> createState() => _RateOrderSheetState();
}

class _RateOrderSheetState extends ConsumerState<RateOrderSheet> {
  final _textController = TextEditingController();
  int _stars = 5;
  XFile? _photo;
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) setState(() => _photo = picked);
    } catch (_) {
      // No permission / picker unavailable — just skip the photo, not fatal.
    }
  }

  Future<void> _submit() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    setState(() => _submitting = true);

    String? photoUrl;
    if (_photo != null) {
      final bytes = await _photo!.readAsBytes();
      final ext = _photo!.name.contains('.') ? _photo!.name.split('.').last.toLowerCase() : 'jpg';
      final uploadResult = await AsyncValue.guard(
        () => ref.read(reviewPhotoUploaderProvider).upload(uid: uid, orderId: widget.order.id, bytes: bytes, fileExtension: ext),
      );
      photoUrl = uploadResult.value;
    }

    final userName = ref.read(appUserProvider).value?.displayName;
    final userPhoto = ref.read(appUserProvider).value?.photoUrl;

    for (final item in widget.order.items) {
      await ref.read(reviewActionsProvider).add(Review(
            id: '',
            bookId: item.bookId,
            orderId: widget.order.id,
            userId: uid,
            userName: (userName?.isEmpty ?? true) ? 'Reader' : userName!,
            userPhotoUrl: userPhoto,
            rating: _stars,
            text: _textController.text.trim(),
            photoUrl: photoUrl,
          ));
    }
    await ref.read(orderRepositoryProvider).markRated(widget.order.id);

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Rate this order', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${widget.order.items.length} item${widget.order.items.length == 1 ? '' : 's'} · your rating applies to each',
                style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    onPressed: () => setState(() => _stars = i + 1),
                    icon: Icon(i < _stars ? Icons.star_rounded : Icons.star_outline_rounded, color: colors.star, size: 32),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                maxLines: 3,
                style: TextStyle(color: colors.textPrimary),
                decoration: const InputDecoration(hintText: 'Share your thoughts about these books (optional)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(_photo == null ? 'Add a photo (optional)' : 'Photo selected'),
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Submit Rating', isLoading: _submitting, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
