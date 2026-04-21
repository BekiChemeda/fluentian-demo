import 'package:dio/dio.dart';

import '../storage/token_store.dart';

class ApiClient {
  ApiClient({required this.baseUrl, required this.tokenStore}) {
    dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStore.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    dio.interceptors.add(_AuthRefreshInterceptor(dio: dio, tokenStore: tokenStore));
  }

  late final Dio dio;
  final String baseUrl;
  final TokenStore tokenStore;
}

class _AuthRefreshInterceptor extends Interceptor {
  _AuthRefreshInterceptor({required this.dio, required this.tokenStore});

  final Dio dio;
  final TokenStore tokenStore;
  bool _isRefreshing = false;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;

    if (status != 401 || path.contains('/auth/login') || path.contains('/auth/register') || path.contains('/auth/refresh')) {
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      handler.next(err);
      return;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await tokenStore.getRefreshToken();
      if (refreshToken == null) {
        await tokenStore.clear();
        handler.next(err);
        return;
      }

      final response = await dio.post('/auth/refresh', data: {'refresh_token': refreshToken});
      final accessToken = response.data['access_token'] as String;
      final newRefreshToken = response.data['refresh_token'] as String;
      await tokenStore.saveTokens(accessToken: accessToken, refreshToken: newRefreshToken);

      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $accessToken';
      final retryResponse = await dio.fetch(requestOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      await tokenStore.clear();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}
