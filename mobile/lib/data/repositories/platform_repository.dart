import '../../core/network/api_client.dart';
import '../models/platform_models.dart';

class PlatformRepository {
  PlatformRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<LanguageModel>> getLanguages() async {
    final response = await apiClient.dio.get('/languages');
    final items = (response.data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LanguageModel.fromJson)
        .toList()
      ..sort((a, b) => a.englishName.compareTo(b.englishName));
    return items;
  }

  Future<List<CourseModel>> getCourses() async {
    final response = await apiClient.dio.get(
      '/courses',
      queryParameters: {'page': 1, 'page_size': 50},
    );
    return (response.data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CourseModel.fromJson)
        .toList();
  }

  Future<LearningPathModel> getLearningPath() async {
    final response = await apiClient.dio.get('/learning-paths/me');
    return LearningPathModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SubscriptionModel> getSubscription() async {
    final response = await apiClient.dio.get('/subscriptions/me');
    return SubscriptionModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<UsageItemModel>> getUsage() async {
    final response = await apiClient.dio.get('/usage/me');
    return (response.data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UsageItemModel.fromJson)
        .toList();
  }

  Future<AiResultModel> explain({
    required String text,
    int? lessonId,
  }) async {
    final response = await apiClient.dio.post('/ai/explain', data: {
      'text': text,
      if (lessonId != null) 'lesson_id': lessonId,
      'source_type': 'lesson',
    });
    return AiResultModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AiResultModel> correct(String text) async {
    final response = await apiClient.dio.post('/ai/correct', data: {
      'text': text,
      'source_type': 'chat',
    });
    return AiResultModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AiResultModel> pronunciationFeedback(String text) async {
    final response = await apiClient.dio.post(
      '/ai/pronunciation-feedback',
      data: {
        'text': text,
        'source_type': 'pronunciation',
      },
    );
    return AiResultModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<TutorProfileModel>> getTutors() async {
    final response = await apiClient.dio.get(
      '/tutors',
      queryParameters: {'page': 1, 'page_size': 50},
    );
    return (response.data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TutorProfileModel.fromJson)
        .toList();
  }

  Future<List<BookingModel>> getBookings() async {
    final response = await apiClient.dio.get(
      '/bookings/me',
      queryParameters: {'page': 1, 'page_size': 50},
    );
    return (response.data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(BookingModel.fromJson)
        .toList();
  }

  Future<BookingModel> createBooking({
    required int tutorUserId,
    required DateTime startsAt,
    required DateTime endsAt,
    required String topic,
  }) async {
    final response = await apiClient.dio.post('/bookings', data: {
      'tutor_user_id': tutorUserId,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'topic': topic,
    });
    return BookingModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<OpportunityModel>> getOpportunities() async {
    final response = await apiClient.dio.get(
      '/opportunities',
      queryParameters: {'page': 1, 'page_size': 50},
    );
    return (response.data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OpportunityModel.fromJson)
        .toList();
  }

  Future<void> saveOpportunity(String id) async {
    await apiClient.dio.post('/opportunities/$id/save');
  }

  Future<String> requestOpportunityGuidance({
    required String id,
    required String question,
  }) async {
    final response = await apiClient.dio.post(
      '/opportunities/$id/guidance-request',
      data: {'question': question},
    );
    return response.data['ai_response']?.toString() ?? '';
  }
}
