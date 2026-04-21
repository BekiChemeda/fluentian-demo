import '../../core/network/api_client.dart';

class CulturalTopicData {
  const CulturalTopicData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.heroTitle,
    required this.imagePlaceholder,
    required this.culturalCards,
    required this.starterPrompts,
    required this.orderIndex,
  });

  final int id;
  final String title;
  final String subtitle;
  final String heroTitle;
  final String imagePlaceholder;
  final List<String> culturalCards;
  final List<String> starterPrompts;
  final int orderIndex;

  factory CulturalTopicData.fromJson(Map<String, dynamic> json) {
    return CulturalTopicData(
      id: json['id'] as int,
      title: (json['title'] as String?) ?? 'Cultural Topic',
      subtitle: (json['subtitle'] as String?) ?? '',
      heroTitle: (json['hero_title'] as String?) ?? '',
      imagePlaceholder: (json['image_placeholder'] as String?) ?? 'image.jpg',
      culturalCards: (json['cultural_cards'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      starterPrompts: (json['starter_prompts'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }
}

class AiChatResult {
  const AiChatResult({
    required this.reply,
    required this.corrected,
    required this.success,
    this.correction,
    this.errorCode,
    this.errorMessage,
  });

  final String reply;
  final bool corrected;
  final bool success;
  final String? correction;
  final String? errorCode;
  final String? errorMessage;
}

class AiChatTurn {
  const AiChatTurn({required this.role, required this.message});

  final String role;
  final String message;

  Map<String, dynamic> toJson() => {
        'role': role,
        'message': message,
      };
}

class CommunityRepository {
  CommunityRepository(this.apiClient);

  final ApiClient apiClient;

  Future<Map<String, dynamic>> findMatch() async {
    final response = await apiClient.dio.get('/match');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> matchStatus() async {
    final response = await apiClient.dio.get('/match/status');
    return response.data as Map<String, dynamic>;
  }

  Future<void> leaveMatch() async {
    await apiClient.dio.post('/match/leave');
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
    });
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
    });
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final response = await apiClient.dio.get('/user/stats');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage({
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
    final response = await apiClient.dio
        .get('/chat/messages', queryParameters: {'peer_id': peerId});
    final items = (response.data['items'] as List).cast<Map<String, dynamic>>();
    return items;
  }

  Future<AiChatResult> aiChat(String body, {List<AiChatTurn> history = const []}) async {
    final response = await apiClient.dio.post('/chat/ai', data: {
      'body': body,
      'history': history.map((item) => item.toJson()).toList(),
    });
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid AI response shape');
    }

    final reply = (data['reply'] as String?)?.trim() ?? '';
    if (reply.isEmpty) {
      throw const FormatException('AI reply is missing');
    }

    return AiChatResult(
      reply: reply,
      corrected: data['corrected'] as bool? ?? false,
      correction: data['correction'] as String?,
      success: data['success'] as bool? ?? true,
      errorCode: data['error_code'] as String?,
      errorMessage: data['error_message'] as String?,
    );
  }

  Future<List<CulturalTopicData>> getCulturalTopics() async {
    final response = await apiClient.dio.get('/cultural/topics');
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid cultural topics response shape');
    }

    final items = (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CulturalTopicData.fromJson)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return items;
  }
}
