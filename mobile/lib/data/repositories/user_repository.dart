import '../../core/network/api_client.dart';
import '../models/user_model.dart';

class UserRepository {
  UserRepository(this.apiClient);

  final ApiClient apiClient;

  Future<UserModel> getMe() async {
    final response = await apiClient.dio.get('/user/me');
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserModel> updateMe({
    String? nativeLanguage,
    String? targetLanguage,
    int? dailyXpGoal,
  }) async {
    final response = await apiClient.dio.patch(
      '/user/me',
      data: {
        if (nativeLanguage != null) 'native_language': nativeLanguage,
        if (targetLanguage != null) 'target_language': targetLanguage,
        if (dailyXpGoal != null) 'daily_xp_goal': dailyXpGoal,
      },
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }
}
