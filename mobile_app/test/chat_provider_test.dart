import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/chat/chat_provider.dart';
import 'package:mobile_app/features/chat/chat_service.dart';
import 'package:mobile_app/features/chat/conversation_service.dart';

import 'fake_chat_backend.dart';

void main() {
  late FakeChatBackend backend;
  late ChatProvider chat;

  setUp(() {
    backend = FakeChatBackend();
    chat = ChatProvider(
      chatService: ChatService(client: backend.dio),
      conversationService: ConversationService(client: backend.dio),
    );
  });

  test('reopens the most recent conversation on start', () async {
    backend.seedConversation('Older', 2);
    final latest = backend.seedConversation('Latest', 4);

    await chat.openLatest();

    expect(chat.conversationId, latest);
    expect(chat.title, 'Latest');
    expect(chat.messages.map((m) => m.content).last, 'Latest message 3');
    expect(chat.conversations.map((c) => c.title), ['Latest', 'Older']);
  });

  test('starts empty when there is no history yet', () async {
    await chat.openLatest();
    expect(chat.conversationId, isNull);
    expect(chat.messages, isEmpty);
  });

  test('long chats load in pages, older ones on request', () async {
    final id = backend.seedConversation('Long', ChatProvider.pageSize + 10);

    await chat.openConversation(id);
    expect(chat.messages, hasLength(ChatProvider.pageSize));
    expect(chat.hasOlder, isTrue);
    expect(chat.messages.first.content, 'Long message 10');

    await chat.loadOlder();
    expect(chat.messages, hasLength(ChatProvider.pageSize + 10));
    expect(chat.messages.first.content, 'Long message 0');
    expect(chat.hasOlder, isFalse);
  });

  test(
    'first message of a new chat creates it and it appears in history',
    () async {
      chat.startNewConversation();

      final reply = await chat.sendMessage('Plan my week');

      expect(reply?.content, 'Reply to: Plan my week');
      expect(chat.conversationId, isNotNull);
      expect(chat.messages.map((m) => m.content), [
        'Plan my week',
        'Reply to: Plan my week',
      ]);
      expect(chat.messages.every((m) => !m.isLocal), isTrue);

      await chat.loadConversations();
      expect(chat.conversations.first.title, 'Plan my week');
    },
  );

  test('switching back to an old chat shows its messages', () async {
    final first = backend.seedConversation('First', 2);
    final second = backend.seedConversation('Second', 2);

    await chat.openConversation(second);
    await chat.sendMessage('more');
    await chat.openConversation(first);

    expect(chat.messages.map((m) => m.content), [
      'First message 0',
      'First message 1',
    ]);
  });

  test('a failed send keeps the text and shows an error', () async {
    backend.failChat = true;
    final id = backend.seedConversation('Chat', 0);
    await chat.openConversation(id);

    final reply = await chat.sendMessage('hello');

    expect(reply, isNull);
    expect(chat.messages.first.content, 'hello');
    expect(chat.messages.last.isError, isTrue);
    expect(chat.messages.last.content, contains('AI provider is unavailable.'));
    expect(chat.isSending, isFalse);
  });

  test('rename and delete update the history', () async {
    final keep = backend.seedConversation('Keep', 1);
    final drop = backend.seedConversation('Drop', 1);
    await chat.loadConversations();
    await chat.openConversation(drop);

    await chat.renameConversation(keep, '  Holiday plans ');
    expect(
      chat.conversations.firstWhere((c) => c.id == keep).title,
      'Holiday plans',
    );

    await chat.deleteConversation(drop);
    expect(chat.conversations.map((c) => c.id), [keep]);
    expect(chat.conversationId, isNull, reason: 'the open chat was deleted');
  });

  test('logout forgets everything', () async {
    backend.seedConversation('Private', 2);
    await chat.openLatest();

    chat.clear();

    expect(chat.conversations, isEmpty);
    expect(chat.messages, isEmpty);
    expect(chat.conversationId, isNull);
  });
}
