import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';

class AuthRepository {
  AuthRepository({required this.apiClient, required this.tokenStore});

  final ApiClient apiClient;
  final TokenStore tokenStore;

  Future<void> register({
    required String email,
    required String password,
    required String nativeLanguage,
    required String targetLanguage,
    required int dailyXpGoal,
  }) async {
    final response = await apiClient.dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'native_language': nativeLanguage,
      'target_language': targetLanguage,
      'daily_xp_goal': dailyXpGoal,
    });
    await tokenStore.saveTokens(
      accessToken: response.data['access_token'] as String,
      refreshToken: response.data['refresh_token'] as String,
    );
  }

  Future<void> login({required String email, required String password}) async {
    final response = await apiClient.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await tokenStore.saveTokens(
      accessToken: response.data['access_token'] as String,
      refreshToken: response.data['refresh_token'] as String,
    );
  }

  Future<void> logout() => tokenStore.clear();
}
