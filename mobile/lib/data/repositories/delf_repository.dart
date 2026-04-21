import '../../core/network/api_client.dart';
import '../models/delf_model.dart';

class DelfRepository {
  DelfRepository(this.apiClient);

  final ApiClient apiClient;

  Future<List<DelfTestSummary>> listTests() async {
    final response = await apiClient.dio.get('/delf/tests');
    final items = (response.data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(DelfTestSummary.fromJson)
        .toList();
    return items;
  }

  Future<DelfTestDetail> getTest(int testId) async {
    final response = await apiClient.dio.get('/delf/tests/$testId');
    return DelfTestDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DelfSubmitResult> submit(int testId, Map<String, String> answers) async {
    final answerItems = answers.entries
        .map((entry) => {'question_id': entry.key, 'answer': entry.value})
        .toList();
    final response = await apiClient.dio.post('/delf/tests/$testId/submit', data: {'answers': answerItems});
    return DelfSubmitResult.fromJson(response.data as Map<String, dynamic>);
  }
}
