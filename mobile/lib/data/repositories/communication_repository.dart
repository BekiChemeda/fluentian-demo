import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';

class CommunicationRepository {
  CommunicationRepository({required this.apiClient, required this.tokenStore});

  static const Uuid _uuid = Uuid();

  final ApiClient apiClient;
  final TokenStore tokenStore;

  Map<String, String> _idempotencyHeaders() {
    return {'Idempotency-Key': _uuid.v4()};
  }

  Future<Map<String, dynamic>> joinQueue({
    required String preferredMode,
    required String learningIntent,
    required String cefrLevel,
    required bool recordingConsent,
  }) async {
    final response = await apiClient.dio.post('/queue/join', data: {
      'preferred_mode': preferredMode,
      'learning_intent': learningIntent,
      'cefr_level': cefrLevel,
      'recording_consent': recordingConsent,
    }, options: Options(headers: _idempotencyHeaders()));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> leaveQueue() async {
    final response = await apiClient.dio.post(
      '/queue/leave',
      options: Options(headers: _idempotencyHeaders()),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> endSession({
    required int sessionId,
    required int duration,
    required int endedBy,
  }) async {
    final response = await apiClient.dio.post('/session/end', data: {
      'session_id': sessionId,
      'duration': duration,
      'ended_by': endedBy,
    }, options: Options(headers: _idempotencyHeaders()));
    return response.data as Map<String, dynamic>;
  }

  Future<void> reportUser({
    required int sessionId,
    required int reportedUserId,
    required String reason,
  }) async {
    await apiClient.dio.post('/session/report', data: {
      'session_id': sessionId,
      'reported_user_id': reportedUserId,
      'reason': reason,
    }, options: Options(headers: _idempotencyHeaders()));
  }

  Future<void> blockUser({
    required int targetUserId,
    String reason = 'safety_block',
  }) async {
    await apiClient.dio.post('/safety/block', data: {
      'user_id': targetUserId,
      'reason': reason,
    }, options: Options(headers: _idempotencyHeaders()));
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final response = await apiClient.dio.get('/user/stats');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendTextMessage({
    required int receiverId,
    required String body,
  }) async {
    final response = await apiClient.dio.post('/chat/send', data: {
      'receiver_id': receiverId,
      'body': body,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listMessages(int peerId) async {
    final response = await apiClient.dio.get(
      '/chat/messages',
      queryParameters: {'peer_id': peerId},
    );
    final items = (response.data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return items;
  }

  Future<WebSocketChannel> connectSocket() async {
    final token = await tokenStore.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Missing access token');
    }

    final baseUri = Uri.parse(apiClient.baseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final wsUri = Uri(
      scheme: wsScheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: '/ws/match',
      queryParameters: {'token': token},
    );
    return WebSocketChannel.connect(wsUri);
  }

  Map<String, dynamic> encodeEvent({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    return {
      'type': type,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
    };
  }

  String serializeEvent({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    return jsonEncode(encodeEvent(type: type, payload: payload));
  }
}
