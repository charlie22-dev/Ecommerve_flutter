import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/store_message.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../message_providers.dart';

/// A chat in BookVerse's style, shared by the customer's chat and the
/// admin's reply screen: newest at the bottom, your messages on the right in
/// ink, theirs on the left in a soft blue with their avatar, a date chip per
/// day, and messages a few minutes apart grouped into one block.
class ChatThread extends StatelessWidget {
  const ChatThread({
    super.key,
    required this.messages,
    required this.isMine,
    required this.otherAvatar,
    this.showTypingIndicator = false,
  });

  /// Oldest first.
  final List<StoreMessage> messages;
  final bool Function(StoreMessage m) isMine;
  final Widget otherAvatar;

  /// When true, shows a live animated "…" bubble from the other side.
  final bool showTypingIndicator;

  static const _groupGap = Duration(minutes: 5);

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  bool _grouped(StoreMessage a, StoreMessage b) =>
      isMine(a) == isMine(b) &&
      a.createdAt != null &&
      b.createdAt != null &&
      b.createdAt!.difference(a.createdAt!).abs() < _groupGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubble = (constraints.maxWidth * 0.72).clamp(0.0, 480.0);
        // +1 extra item slot at index 0 (reversed list = visually top) for typing
        final extraItem = showTypingIndicator ? 1 : 0;
        return ListView.builder(
          // Reversed so the thread sits at the bottom, newest just above
          // the input, and new messages appear there without scrolling.
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: messages.length + extraItem,
          itemBuilder: (context, i) {
            // First slot (bottom of reversed list) = typing indicator
            if (showTypingIndicator && i == 0) {
              return _TypingIndicatorBubble(avatar: otherAvatar);
            }
            final index = messages.length - 1 - (i - extraItem);
            final m = messages[index];
            final older = index > 0 ? messages[index - 1] : null;
            final newer = index < messages.length - 1 ? messages[index + 1] : null;
            final newDay = older == null || !_sameDay(older.createdAt, m.createdAt);
            final lastInGroup = newer == null || !_grouped(m, newer) || !_sameDay(m.createdAt, newer.createdAt);
            return Column(
              key: ValueKey(m.id),
              children: [
                if (newDay && m.createdAt != null) _DateChip(day: m.createdAt!),
                _Bubble(
                  message: m,
                  mine: isMine(m),
                  lastInGroup: lastInGroup,
                  maxWidth: maxBubble,
                  avatar: otherAvatar,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Animated three-dot typing indicator bubble shown on the left (other side).
class _TypingIndicatorBubble extends StatefulWidget {
  const _TypingIndicatorBubble({required this.avatar});
  final Widget avatar;
  @override
  State<_TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<_TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          widget.avatar,
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i / 3;
                    final val = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
                    final opacity =
                        (0.3 + 0.7 * (val < 0.5 ? val * 2 : (1 - val) * 2)).clamp(0.3, 1.0);
                    return Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: colors.textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    final label = d == today
        ? 'Today'
        : d == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : DateFormat.yMMMd().format(day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.lastInGroup,
    required this.maxWidth,
    required this.avatar,
  });

  final StoreMessage message;
  final bool mine;
  final bool lastInGroup;
  final double maxWidth;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const r = Radius.circular(18);
    // The corner nearest the sender gets a small "tail" on the last bubble.
    const tail = Radius.circular(6);
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? colors.ink : colors.accentBlueMuted,
        borderRadius: BorderRadius.only(
          topLeft: r,
          topRight: r,
          bottomLeft: !mine && lastInGroup ? tail : r,
          bottomRight: mine && lastInGroup ? tail : r,
        ),
      ),
      child: Text(
        message.displayContent,
        style: TextStyle(color: mine ? colors.onInk : colors.textPrimary, fontSize: 14, height: 1.35),
      ),
    );

    final time = message.createdAt == null
        ? null
        : Padding(
            padding: EdgeInsets.only(top: 4, left: mine ? 0 : 40),
            child: Text(
              DateFormat.jm().format(message.createdAt!),
              style: TextStyle(color: colors.textTertiary, fontSize: 11),
            ),
          );

    return _FadeIn(
      child: Padding(
        padding: EdgeInsets.only(bottom: lastInGroup ? 12 : 3),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!mine) ...[
                  // Avatar once per group, on its last bubble; a spacer keeps
                  // the other bubbles aligned.
                  SizedBox(width: 32, child: lastInGroup ? avatar : null),
                  const SizedBox(width: 8),
                ],
                Flexible(child: bubble),
              ],
            ),
            if (lastInGroup && time != null) time,
          ],
        ),
      ),
    );
  }
}

/// New messages ease in: a short fade and a 6px rise, nothing bouncy.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 6 * (1 - t)), child: child),
      ),
    );
  }
}

/// The message box: a rounded field and an ink send button that only lights
/// up when there's something to send. Enter sends.
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.hint,
    required this.onSend,
    this.onTypingChanged,
  });

  final String hint;

  /// Returns once sent; the field clears only if it didn't throw.
  final Future<void> Function(String text) onSend;

  /// Called with `true` when the user starts typing and `false` when they
  /// clear the field or send — use this to broadcast typing state.
  final void Function(bool isTyping)? onTypingChanged;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _wasTyping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
      final isTyping = _controller.text.trim().isNotEmpty;
      // Update the Riverpod typing provider.
      ref.read(isUserTypingProvider.notifier).state = isTyping;
      // Notify the parent screen (which broadcasts to Supabase Realtime).
      if (isTyping != _wasTyping) {
        _wasTyping = isTyping;
        widget.onTypingChanged?.call(isTyping);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      _controller.clear();
      // Clear the typing indicator after sending.
      ref.read(isUserTypingProvider.notifier).state = false;
      if (_wasTyping) {
        _wasTyping = false;
        widget.onTypingChanged?.call(false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canSend = _controller.text.trim().isNotEmpty && !_sending;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(color: colors.surface, border: Border(top: BorderSide(color: colors.border))),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  filled: true,
                  fillColor: colors.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: colors.ink),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: canSend || _sending ? 1 : 0.35,
              duration: const Duration(milliseconds: 150),
              child: IconButton.filled(
                tooltip: 'Send',
                onPressed: canSend ? _send : null,
                style: IconButton.styleFrom(
                  backgroundColor: colors.ink,
                  foregroundColor: colors.onInk,
                  disabledBackgroundColor: colors.ink,
                  disabledForegroundColor: colors.onInk,
                  fixedSize: const Size(46, 46),
                ),
                icon: _sending
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onInk))
                    : const Icon(Icons.arrow_upward_rounded, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar + name + subtitle for the chat's app bar.
class ChatHeader extends StatelessWidget {
  const ChatHeader({super.key, required this.avatar, required this.name, required this.subtitle, this.verified = false});

  final Widget avatar;
  final String name;
  final String subtitle;

  /// Shows a check badge next to the name (the official store).
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (verified) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.verified_rounded, size: 16, color: colors.accentBlue),
                  ],
                ],
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textTertiary, fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// BookVerse Store's avatar: the brand mark in a light circle.
class StoreAvatar extends StatelessWidget {
  const StoreAvatar({super.key, this.radius = 16});
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: EdgeInsets.all(radius * 0.3),
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colors.border),
      ),
      child: Image.asset('assets/branding/mark.png', semanticLabel: 'BookVerse Store'),
    );
  }
}
