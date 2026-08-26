import 'package:dio/dio.dart';
import 'package:github_manager/core/constants/github_api.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';

class GitHubAuthRepository {
  GitHubAuthRepository(
    this._secureStorage,
    this._localDatabase, {
    Dio? dio,
  }) : _dio = dio ?? Dio(BaseOptions(baseUrl: GitHubApi.baseUrl));

  final SecureStorageService _secureStorage;
  final LocalDatabase _localDatabase;
  final Dio _dio;

  Future<bool> isConnected() => _secureStorage.hasGitHubToken();

  Future<void> connectWithToken(String rawToken) async {
    final token = rawToken.trim();
    if (token.isEmpty) {
      throw const AuthenticationRequiredException();
    }

    try {
      await _dio.get<Object>(
        '/user',
        options: Options(
          headers: {
            'Accept': GitHubApi.accept,
            'X-GitHub-Api-Version': GitHubApi.apiVersion,
            'Authorization': 'Bearer $token',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw const AuthenticationRequiredException();
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const NetworkRequiredException();
      }
      throw const UnexpectedAppException('TOKEN_VALIDATION_FAILED');
    }

    await _secureStorage.writeGitHubToken(token);
  }

  Future<void> disconnect() async {
    await _secureStorage.deleteGitHubToken();
    await _localDatabase.clearGitHubCache();
  }
}
