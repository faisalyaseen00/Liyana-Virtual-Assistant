import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/chat/chat_provider.dart';
import 'package:mobile_app/features/chat/chat_service.dart';
import 'package:mobile_app/features/chat/conversation_service.dart';
import 'package:mobile_app/features/chat/conversations_screen.dart';
import 'package:provider/provider.dart';

import 'fake_chat_backend.dart';

void main() {
  testWidgets('lists chats and opens one on tap', (tester) async {
    final backend = FakeChatBackend();
    backend.seedConversation('Trip to Lahore', 2);
    final study = backend.seedConversation('Study plan', 2);
    final chat = ChatProvider(
      chatService: ChatService(client: backend.dio),
      conversationService: ConversationService(client: backend.dio),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: chat,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ConversationsScreen(),
                  ),
                ),
                child: const Text('open history'),
              ),
            ),
          ),
        ),
      ),
    );

    chat.loadConversations();
    await tester.tap(find.text('open history'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Study plan'), findsOneWidget);
    expect(find.text('Trip to Lahore'), findsOneWidget);

    await tester.tap(find.text('Study plan'));
    await tester.pumpAndSettle();

    expect(find.text('open history'), findsOneWidget, reason: 'went back');
    expect(chat.conversationId, study);
    expect(chat.messages.last.content, 'Study plan message 1');
  });

  test('chat times read naturally', () {
    final now = DateTime(2026, 11, 23, 18);
    expect(formatChatTime(DateTime(2026, 11, 23, 9, 5), now: now), '09:05');
    expect(formatChatTime(DateTime(2026, 11, 22, 23), now: now), 'Yesterday');
    expect(formatChatTime(DateTime(2026, 3, 4), now: now), '4 Mar');
    expect(formatChatTime(DateTime(2025, 3, 4), now: now), '4 Mar 2025');
  });
}
