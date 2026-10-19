import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/store_message.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../messages/data/typing_service.dart';
import '../../messages/presentation/widgets/chat_thread.dart';
import 'admin_providers.dart';
import 'widgets/admin_table.dart';

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
                leading: InitialAvatar(t.customer.label, photoUrl: t.customer.photoUrl, radius: 20),
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
  TypingService? _typingService;
  bool _customerIsTyping = false;

  @override
  void initState() {
    super.initState();
    // Subscribe to the customer's typing channel as the store side.
    _typingService = TypingService(userId: widget.customerUid, senderRole: 'store');
    _typingService!.onOtherTyping.listen((isTyping) {
      if (mounted) setState(() => _customerIsTyping = isTyping);
    });
  }

  void _onTypingChanged(bool isTyping) {
    _typingService?.sendTyping(isTyping);
  }

  @override
  void dispose() {
    _typingService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final customer = ref.watch(adminCustomerProvider(widget.customerUid)).value;
    final messagesAsync = ref.watch(adminThreadMessagesProvider(widget.customerUid));
    final name = customer?.label ?? 'Customer';
    final avatar = InitialAvatar(name, photoUrl: customer?.photoUrl);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ChatHeader(
          avatar: InitialAvatar(name, photoUrl: customer?.photoUrl, radius: 18),
          name: name,
          subtitle: customer?.email ?? '',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Expanded(
                child: messagesAsync.when(
                  data: (messages) => ChatThread(
                    messages: messages,
                    isMine: (m) => m.sender == MessageSender.store,
                    otherAvatar: avatar,
                    // Show dots when the customer is actively typing.
                    showTypingIndicator: _customerIsTyping,
                  ),
                  loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
                  error: (e, _) =>
                      Center(child: Text('Could not load this conversation.\n$e', textAlign: TextAlign.center)),
                ),
              ),
              ChatComposer(
                hint: 'Reply as BookVerse Store…',
                onSend: (text) => ref.read(adminRepositoryProvider).sendStoreReply(widget.customerUid, text),
                onTypingChanged: _onTypingChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

