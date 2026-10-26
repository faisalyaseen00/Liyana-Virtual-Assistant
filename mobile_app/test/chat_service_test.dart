import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/chat/chat_service.dart';

class FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (options.path == '/conversations') {
      return _response('{"id":"00000000-0000-0000-0000-000000000001"}', 200);
    }

    return _response(
      '{'
      '"user_message":{'
      '"id":"00000000-0000-0000-0000-000000000002",'
      '"conversation_id":"00000000-0000-0000-0000-000000000001",'
      '"role":"user",'
      '"content":"Hello"'
      '},'
      '"assistant_message":{'
      '"id":"00000000-0000-0000-0000-000000000003",'
      '"conversation_id":"00000000-0000-0000-0000-000000000001",'
      '"role":"assistant",'
      '"content":"Hello from Liyana"'
      '}'
      '}',
      200,
    );
  }

  ResponseBody _response(String body, int statusCode) {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'voice text can use the chat request and receive assistant text',
    () async {
      final adapter = FakeAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final service = ChatService(client: dio);

      final result = await service.sendMessage(content: 'Hello');

      expect(result.conversationId, '00000000-0000-0000-0000-000000000001');
      expect(result.response.assistantMessage.content, 'Hello from Liyana');
      expect(adapter.requests.map((request) => request.path), [
        '/conversations',
        '/conversations/00000000-0000-0000-0000-000000000001/chat',
      ]);
    },
  );
}
