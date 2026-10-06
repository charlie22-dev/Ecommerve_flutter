import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/store_message.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import 'admin_providers.dart';

/// Inbox of customer threads — unanswered ones first.
class AdminMessagesScreen extends ConsumerWidget {
  const AdminMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final threadsAsync = ref.watch(adminThreadsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Messages')),
      body: threadsAsync.when(
        data: (threads) {
          if (threads.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No messages yet',
              message: 'When customers message the store, their conversations show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: threads.length,
            separatorBuilder: (_, _) => Divider(height: 1, indent: 72, color: colors.borderSubtle),
            itemBuilder: (context, i) {
              final t = threads[i];
              final last = t.lastMessage;
              return ListTile(
                onTap: () => context.push('${AppRoute.adminMessages}/${t.customer.uid}'),
                leading: CircleAvatar(
                  backgroundColor: colors.surfaceMuted,
                  child: Text(
                    t.customer.label.characters.first.toUpperCase(),
                    style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(
                  t.customer.label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: t.needsReply ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${last.sender == MessageSender.store ? 'You: ' : ''}${last.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.needsReply ? colors.textPrimary : colors.textTertiary, fontSize: 13),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (last.createdAt != null)
                      Text(DateFormat.MMMd().format(last.createdAt!), style: TextStyle(color: colors.textTertiary, fontSize: 11)),
                    if (t.needsReply) ...[
                      const SizedBox(height: 4),
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: colors.error, shape: BoxShape.circle)),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
        error: (e, _) => Center(child: Text('Could not load messages.\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}

/// One customer's thread, answered as "BookVerse Store".
class AdminConversationScreen extends ConsumerStatefulWidget {
  const AdminConversationScreen({super.key, required this.customerUid});
  final String customerUid;

  @override
  ConsumerState<AdminConversationScreen> createState() => _AdminConversationScreenState();
}

class _AdminConversationScreenState extends ConsumerState<AdminConversationScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(adminRepositoryProvider).sendStoreReply(widget.customerUid, text);
      _input.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final customer = ref.watch(adminCustomerProvider(widget.customerUid)).value;
    final messagesAsync = ref.watch(adminThreadMessagesProvider(widget.customerUid));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer?.label ?? 'Customer'),
            if (customer != null && customer.email.isNotEmpty)
              Text(customer.email, style: TextStyle(color: colors.textTertiary, fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) => ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[messages.length - 1 - i];
                  final fromStore = m.sender == MessageSender.store;
                  return Align(
                    alignment: fromStore ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
                      decoration: BoxDecoration(
                        color: fromStore ? colors.ink : colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.text, style: TextStyle(color: fromStore ? colors.onInk : colors.textPrimary, fontSize: 13.5)),
                          if (m.createdAt != null)
                            Text(
                              DateFormat.MMMd().add_jm().format(m.createdAt!),
                              style: TextStyle(
                                color: (fromStore ? colors.onInk : colors.textTertiary).withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
              error: (e, _) => Center(child: Text('Could not load this conversation.\n$e', textAlign: TextAlign.center)),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(color: colors.textPrimary),
                      decoration: const InputDecoration(hintText: 'Reply as BookVerse Store…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: colors.ink, foregroundColor: colors.onInk),
                    icon: _sending
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onInk))
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
