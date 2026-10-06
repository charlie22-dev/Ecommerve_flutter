import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/widgets/primary_button.dart';
import '../collection_providers.dart';

/// The bottom sheet behind main_basis.png's floating "+" button — names a
/// new collection; books get added to it afterwards from Book Details.
class CreateCollectionSheet extends ConsumerStatefulWidget {
  const CreateCollectionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const CreateCollectionSheet(),
    );
  }

  @override
  ConsumerState<CreateCollectionSheet> createState() => _CreateCollectionSheetState();
}

class _CreateCollectionSheetState extends ConsumerState<CreateCollectionSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await ref.read(collectionActionsProvider).create(
          title: _title.text.trim(),
          description: _description.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New collection', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            style: TextStyle(color: context.colors.textPrimary),
            decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Mindset & Money'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 2,
            style: TextStyle(color: context.colors.textPrimary),
            decoration: const InputDecoration(labelText: 'Description (optional)'),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Create collection', isLoading: _saving, onPressed: _create),
        ],
      ),
    );
  }
}
