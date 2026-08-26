import 'package:dio/dio.dart';
import 'package:github_manager/core/constants/github_api.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';

class GitHubApiClient {
  GitHubApiClient(this._secureStorage, {Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: GitHubApi.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 45),
                sendTimeout: const Duration(seconds: 45),
                headers: const {
                  'Accept': GitHubApi.accept,
                  'X-GitHub-Api-Version': GitHubApi.apiVersion,
                },
              ),
            );

  final SecureStorageService _secureStorage;
  final Dio _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) =>
      _request<T>(
        'GET',
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) =>
      _request<T>(
        'POST',
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) =>
      _request<T>('PATCH', path, data: data, cancelToken: cancelToken);

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) =>
      _request<T>('PUT', path, data: data, cancelToken: cancelToken);

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) =>
      _request<T>('DELETE', path, data: data, cancelToken: cancelToken);

  Future<void> downloadRedirectedFile(
    String path,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final token = await _secureStorage.readGitHubToken();
    if (token == null) {
      throw const AuthenticationRequiredException();
    }

    try {
      final redirect = await _dio.get<void>(
        path,
        cancelToken: cancelToken,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status == 302,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      final location = redirect.headers.value('location');
      if (location == null || location.isEmpty) {
        throw const UnexpectedAppException('ARTIFACT_REDIRECT_MISSING');
      }

      final downloadDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
      await downloadDio.download(
        location,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on AppException {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Response<T>> _request<T>(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final token = await _secureStorage.readGitHubToken();
    if (token == null) {
      throw const AuthenticationRequiredException();
    }

    try {
      return await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  static AppException _mapDioException(DioException error) {
    if (CancelToken.isCancel(error)) {
      return const UnexpectedAppException('REQUEST_CANCELLED');
    }

    final response = error.response;
    final status = response?.statusCode;
    final remaining = response?.headers.value('x-ratelimit-remaining');

    if (status == 401) {
      return const AuthenticationRequiredException();
    }
    if (status == 404) {
      return const GitHubNotFoundException();
    }
    if (status == 429) {
      return const GitHubRateLimitException();
    }
    if (status == 403 && remaining == '0') {
      return const GitHubRateLimitException();
    }
    if (status == 403) {
      return const GitHubPermissionException();
    }
    if (status == 409) {
      return const GitHubConflictException();
    }
    if (status == 422) {
      return const GitHubValidationException();
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const NetworkRequiredException();
    }

    return UnexpectedAppException('GITHUB_HTTP_${status ?? 'UNKNOWN'}');
  }
}
