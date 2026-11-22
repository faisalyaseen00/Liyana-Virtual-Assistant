import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import 'chat_model.dart';
import 'conversation_model.dart';

/// Talks to the backend's /conversations endpoints (chat history).
class ConversationService {
  final Dio _client;

  ConversationService({Dio? client}) : _client = client ?? ApiClient.dio;

  /// Newest activity first.
  Future<List<Conversation>> listConversations() async {
    try {
      final response = await _client.get('/conversations');
      return (response.data as List)
          .map(
            (item) =>
                Conversation.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallback: 'Could not load your chats.');
    }
  }

  /// The newest [limit] messages, oldest first; with [beforeId], the ones
  /// before that message.
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeId,
  }) async {
    try {
      final response = await _client.get(
        '/conversations/$conversationId/messages',
        queryParameters: {'limit': limit, 'before': ?beforeId},
      );
      return (response.data as List)
          .map(
            (item) =>
                ChatMessage.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallback: 'Could not load this chat.');
    }
  }

  Future<Conversation> rename(String conversationId, String title) async {
    try {
      final response = await _client.patch(
        '/conversations/$conversationId',
        data: {'title': title},
      );
      return Conversation.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallback: 'Could not rename the chat.');
    }
  }

  Future<void> delete(String conversationId) async {
    try {
      await _client.delete('/conversations/$conversationId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallback: 'Could not delete the chat.');
    }
  }
}
