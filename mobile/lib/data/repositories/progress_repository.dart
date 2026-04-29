import '../../core/network/api_client.dart';
import '../models/progress_model.dart';

class ProgressRepository {
  ProgressRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<ProgressItemModel>> getProgress() async {
    final response = await apiClient.dio.get('/progress/me');
    final items = (response.data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ProgressItemModel.fromJson).toList();
  }
}
