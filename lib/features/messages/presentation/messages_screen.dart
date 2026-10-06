import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_color_tokens.dart';
import 'message_providers.dart';

/// BookVerse has one seller (the store itself), so this "conversations"
/// list only ever has one row — tapping it opens the actual thread. See
/// store_message.dart for why the data model doesn't need a full
/// multi-seller conversations schema.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final threadAsync = ref.watch(storeThreadProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: threadAsync.when(
        data: (thread) {
          final last = thread.isEmpty ? null : thread.last;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push('/messages/store'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colors.ink,
                        child: Icon(Icons.storefront_rounded, color: colors.onInk, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BookVerse Store', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              last?.text ?? 'Start a conversation with our support team',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (err, _) => Center(child: Text('Could not load messages.', style: TextStyle(color: colors.error))),
      ),
    );
  }
}
