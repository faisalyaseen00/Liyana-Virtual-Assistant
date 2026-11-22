import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// In-memory stand-in for /conversations, their messages and /chat.
class FakeChatBackend implements HttpClientAdapter {
  final List<Map<String, dynamic>> conversations = [];
  final Map<String, List<Map<String, dynamic>>> messages = {};
  final List<String> calls = [];
  bool failChat = false;
  int _next = 1;
  int _clock = 0;

  Dio get dio =>
      Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = this;

  /// Adds a conversation with [count] alternating user/assistant messages.
  String seedConversation(String title, int count) {
    final id = 'c${_next++}';
    conversations.insert(0, {
      'id': id,
      'user_id': 'u',
      'title': title,
      'created_at': _stamp(),
      'updated_at': _stamp(),
      'last_message_at': _stamp(),
    });
    messages[id] = [
      for (var i = 0; i < count; i++)
        _message(id, i.isEven ? 'user' : 'assistant', '$title message $i'),
    ];
    return id;
  }

  String _stamp() => DateTime.utc(
    2026,
    11,
    23,
    10,
  ).add(Duration(seconds: _clock++)).toIso8601String();

  Map<String, dynamic> _message(
    String conversationId,
    String role,
    String text,
  ) => {
    'id': 'm${_next++}',
    'conversation_id': conversationId,
    'role': role,
    'content': text,
    'extra_data': null,
    'created_at': _stamp(),
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(
      '${options.method} ${options.uri.path}${options.uri.hasQuery ? '?${options.uri.query}' : ''}',
    );
    final parts = options.path.split('/')..removeWhere((p) => p.isEmpty);
    final id = parts.length > 1 ? parts[1] : null;

    if (parts.length == 1) {
      if (options.method == 'GET') return _json(conversations, 200);
      final created = {
        'id': 'c${_next++}',
        'user_id': 'u',
        'title': 'New Conversation',
        'created_at': _stamp(),
        'updated_at': _stamp(),
        'last_message_at': _stamp(),
      };
      conversations.insert(0, created);
      messages[created['id'] as String] = [];
      return _json(created, 201);
    }

    if (parts.length == 3 && parts[2] == 'messages') {
      var list = messages[id] ?? [];
      final before = options.queryParameters['before'];
      if (before != null) {
        final index = list.indexWhere((m) => m['id'] == before);
        list = list.sublist(0, index);
      }
      final limit = options.queryParameters['limit'] as int?;
      if (limit != null && list.length > limit) {
        list = list.sublist(list.length - limit);
      }
      return _json(list, 200);
    }

    if (parts.length == 3 && parts[2] == 'chat') {
      if (failChat) {
        return _json({'detail': 'AI provider is unavailable.'}, 502);
      }
      final content = (options.data as Map)['content'] as String;
      final user = _message(id!, 'user', content);
      final reply = _message(id, 'assistant', 'Reply to: $content');
      messages[id]!
        ..add(user)
        ..add(reply);
      final conversation = conversations.firstWhere((c) => c['id'] == id);
      if (conversation['title'] == 'New Conversation') {
        conversation['title'] = content;
      }
      conversations
        ..remove(conversation)
        ..insert(0, conversation);
      return _json({'user_message': user, 'assistant_message': reply}, 201);
    }

    if (options.method == 'PATCH') {
      final conversation = conversations.firstWhere((c) => c['id'] == id);
      conversation['title'] = (options.data as Map)['title'];
      return _json(conversation, 200);
    }

    if (options.method == 'DELETE') {
      conversations.removeWhere((c) => c['id'] == id);
      messages.remove(id);
      return ResponseBody.fromString('', 204);
    }

    return _json({'detail': 'Not found'}, 404);
  }

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
