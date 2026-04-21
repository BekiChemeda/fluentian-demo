import '../../core/network/api_client.dart';
import '../models/badge_model.dart';

class BadgeRepository {
  BadgeRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<BadgeModel>> getBadges() async {
    final response = await apiClient.dio.get('/badges');
    final items = (response.data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(BadgeModel.fromJson).toList();
  }
}
