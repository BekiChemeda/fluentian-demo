import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../models/lesson_model.dart';

class LessonRepository {
  LessonRepository(this.apiClient);

  final ApiClient apiClient;
  static const _lessonsCacheKey = 'lessons_cache_v1';

  Future<List<LessonModel>> getLessons() async {
    try {
      final response = await apiClient.dio
          .get('/lessons', queryParameters: {'page': 1, 'page_size': 50});
      final items =
          (response.data['items'] as List).cast<Map<String, dynamic>>();
      final lessons = items.map(LessonModel.fromJson).toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      await _cacheLessons(items);
      return lessons;
    } catch (_) {
      final cached = await _readCachedLessons();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<LessonModel> getLessonById(int id) async {
    final response = await apiClient.dio.get('/lessons/$id');
    return LessonModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> startLesson(int id) async {
    await apiClient.dio.post('/lessons/$id/start');
  }

  Future<Map<String, dynamic>> completeLesson(int id, int score) async {
    final response = await apiClient.dio
        .post('/lessons/$id/complete', data: {'score': score});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> explainLesson({
    required int lessonId,
    required String blockTitle,
    required String blockHint,
    required String blockAnswer,
    required String action,
    String? inlineContext,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/lessons/$lessonId/explain',
        data: {
          'block_title': blockTitle,
          'block_hint': blockHint,
          'block_answer': blockAnswer,
          'action': action,
          'inline_context': inlineContext,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (_) {
      final response = await apiClient.dio.post(
        '/ai/explain',
        data: {
          'text': [
            blockTitle,
            blockHint,
            blockAnswer,
            if (inlineContext != null) inlineContext,
          ].where((item) => item.trim().isNotEmpty).join('\n'),
          'lesson_id': lessonId,
          'source_type': 'lesson',
        },
      );
      return {
        'simple': response.data['result']?.toString() ?? '',
        'examples': const [],
        'rules': const [],
      };
    }
  }

  Future<void> _cacheLessons(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lessonsCacheKey, jsonEncode(items));
  }

  Future<List<LessonModel>> _readCachedLessons() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lessonsCacheKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(LessonModel.fromJson)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    } catch (_) {
      return const [];
    }
  }
}
