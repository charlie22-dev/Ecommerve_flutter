import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/models/store_message.dart';
import 'package:my_app/core/theme/app_color_tokens.dart';
import 'package:my_app/features/messages/presentation/widgets/chat_thread.dart';

void main() {
  testWidgets('newest message is at the bottom; mine on the right, theirs on the left', (tester) async {
    final day = DateTime(2026, 10, 13);
    final messages = [
      StoreMessage(id: '1', uid: 'u', sender: MessageSender.user, text: 'hello', createdAt: day.add(const Duration(hours: 11, minutes: 52))),
      StoreMessage(id: '2', uid: 'u', sender: MessageSender.store, text: 'hi', createdAt: day.add(const Duration(hours: 11, minutes: 53))),
      StoreMessage(id: '3', uid: 'u', sender: MessageSender.store, text: 'how you doin?', createdAt: day.add(const Duration(hours: 13, minutes: 9))),
    ];

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColorTokens.light]),
      home: Scaffold(
        body: ChatThread(
          messages: messages, // oldest first, as the repository returns them
          isMine: (m) => m.sender == MessageSender.store, // the admin's view
          otherAvatar: const SizedBox(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final hello = tester.getCenter(find.text('hello'));
    final hi = tester.getCenter(find.text('hi'));
    final newest = tester.getCenter(find.text('how you doin?'));
    expect(newest.dy, greaterThan(hi.dy));
    expect(hi.dy, greaterThan(hello.dy));
    expect(hi.dx, greaterThan(hello.dx), reason: "admin's own replies sit on the right");
  });
}
