import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import 'chat_model.dart';

class ChatService {
  final Dio _client;

  ChatService({Dio? client}) : _client = client ?? ApiClient.dio;

  Future<ChatResult> sendMessage({
    required String content,
    String? conversationId,
  }) async {
    try {
      final id = conversationId ?? await _createConversation();
      final response = await _client.post(
        '/conversations/$id/chat',
        data: {'content': content},
        // The assistant may make two model calls (routing + answer), which
        // can take longer than the default 15 s timeout.
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );

      return ChatResult(
        conversationId: id,
        response: ChatResponse.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallback: 'Unable to send message.');
    }
  }

  Future<String> _createConversation() async {
    final response = await _client.post('/conversations');
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['id'] as String;
  }
}
