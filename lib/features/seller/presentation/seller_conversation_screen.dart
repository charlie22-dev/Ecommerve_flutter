import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/store_message.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../admin/presentation/widgets/admin_table.dart';
import '../../messages/data/typing_service.dart';
import '../../messages/presentation/message_providers.dart';
import '../../messages/presentation/widgets/chat_thread.dart';

/// Seller replies to a specific customer's thread.
class SellerConversationScreen extends ConsumerStatefulWidget {
  const SellerConversationScreen({
    super.key,
    required this.customerUid,
    required this.storeId,
  });

  final String customerUid;
  final String storeId;

  @override
  ConsumerState<SellerConversationScreen> createState() =>
      _SellerConversationScreenState();
}

class _SellerConversationScreenState
    extends ConsumerState<SellerConversationScreen> {
  TypingService? _typingService;
  bool _customerIsTyping = false;

  @override
  void initState() {
    super.initState();
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
    final messagesAsync = ref.watch(
      sellerCustomerThreadProvider((widget.storeId, widget.customerUid)),
    );

    // Try to get the customer's display name from the inbox cache.
    final inbox = ref.watch(sellerInboxProvider(widget.storeId)).value;
    final thread = inbox?.where((t) => t.customer.uid == widget.customerUid).firstOrNull;
    final customerName = thread?.customer.label ?? 'Customer';
    final customerPhoto = thread?.customer.photoUrl;

    final avatar = InitialAvatar(customerName, photoUrl: customerPhoto);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ChatHeader(
          avatar: InitialAvatar(customerName, photoUrl: customerPhoto, radius: 18),
          name: customerName,
          subtitle: thread?.customer.email ?? '',
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
                    showTypingIndicator: _customerIsTyping,
                  ),
                  loading: () => Center(child: CircularProgressIndicator(color: colors.ink)),
                  error: (e, _) => Center(
                    child: Text('Could not load conversation.\n$e', textAlign: TextAlign.center),
                  ),
                ),
              ),
              ChatComposer(
                hint: 'Reply as your store…',
                onSend: (text) async {
                  await ref
                      .read(messageRepositoryProvider)
                      .sendSellerReply(widget.customerUid, widget.storeId, text);
                },
                onTypingChanged: _onTypingChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
