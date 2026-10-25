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
      );

      return ChatResult(
        conversationId: id,
        response: ChatResponse.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        ),
      );
    } on DioException catch (error) {
      final detail = error.response?.data is Map
          ? (error.response?.data['detail'] as String?)
          : null;
      throw ApiException(
        detail ?? error.message ?? 'Unable to send message.',
      );
    }
  }

  Future<String> _createConversation() async {
    final response = await _client.post('/conversations');
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['id'] as String;
  }
}
