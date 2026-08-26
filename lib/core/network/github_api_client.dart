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

    Response<dynamic> redirect;
    try {
      redirect = await _dio.get<dynamic>(
        path,
        cancelToken: cancelToken,
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
    } on DioException catch (error) {
      throw _mapDownloadDioException(
        error,
        endpoint: path,
        stage: 'obter_url',
      );
    }

    final status = redirect.statusCode;
    if (!_isRedirect(status)) {
      throw _downloadHttpFailure(
        endpoint: path,
        stage: 'obter_url',
        status: status,
        data: redirect.data,
        remaining: redirect.headers.value('x-ratelimit-remaining'),
      );
    }

    final location = redirect.headers.value('location');
    if (location == null || location.isEmpty) {
      throw DownloadFailureException(
        'O GitHub não retornou a URL temporária do arquivo.',
        code: 'DOWNLOAD_REDIRECT_MISSING',
        endpoint: path,
        stage: 'obter_url',
        httpStatus: status,
      );
    }

    final downloadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    try {
      await downloadDio.download(
        location,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (error) {
      throw _mapDownloadDioException(
        error,
        endpoint: path,
        stage: 'baixar_arquivo',
        temporaryUrl: true,
      );
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

  static bool _isRedirect(int? status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  static DownloadFailureException _mapDownloadDioException(
    DioException error, {
    required String endpoint,
    required String stage,
    bool temporaryUrl = false,
  }) {
    if (CancelToken.isCancel(error)) {
      return DownloadFailureException(
        'Download cancelado.',
        code: 'DOWNLOAD_CANCELLED',
        endpoint: endpoint,
        stage: stage,
      );
    }

    final response = error.response;
    final status = response?.statusCode;
    if (status != null) {
      if (temporaryUrl && status == 403) {
        return DownloadFailureException(
          'A URL temporária do GitHub expirou antes de concluir o download.',
          code: 'DOWNLOAD_TEMP_URL_EXPIRED',
          endpoint: endpoint,
          stage: stage,
          httpStatus: status,
          apiMessage: _responseMessage(response?.data),
        );
      }
      return _downloadHttpFailure(
        endpoint: endpoint,
        stage: stage,
        status: status,
        data: response?.data,
        remaining: response?.headers.value('x-ratelimit-remaining'),
      );
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return DownloadFailureException(
        'Sem conexão estável com a internet para concluir o download.',
        code: 'DOWNLOAD_NETWORK',
        endpoint: endpoint,
        stage: stage,
      );
    }

    return DownloadFailureException(
      'O download foi interrompido antes de concluir.',
      code: 'DOWNLOAD_INTERRUPTED',
      endpoint: endpoint,
      stage: stage,
      apiMessage: error.message,
    );
  }

  static DownloadFailureException _downloadHttpFailure({
    required String endpoint,
    required String stage,
    required int? status,
    required Object? data,
    required String? remaining,
  }) {
    final apiMessage = _responseMessage(data);
    if (status == 401) {
      return DownloadFailureException(
        'O token do GitHub não é mais válido.',
        code: 'DOWNLOAD_AUTH_REQUIRED',
        endpoint: endpoint,
        stage: stage,
        httpStatus: status,
        apiMessage: apiMessage,
      );
    }
    if ((status == 403 && remaining == '0') || status == 429) {
      return DownloadFailureException(
        'O limite temporário da API do GitHub foi atingido.',
        code: 'DOWNLOAD_RATE_LIMIT',
        endpoint: endpoint,
        stage: stage,
        httpStatus: status,
        apiMessage: apiMessage,
      );
    }
    if (status == 403) {
      return DownloadFailureException(
        'O token não tem permissão para baixar este arquivo.',
        code: 'DOWNLOAD_FORBIDDEN',
        endpoint: endpoint,
        stage: stage,
        httpStatus: status,
        apiMessage: apiMessage,
      );
    }
    if (status == 404) {
      return DownloadFailureException(
        'O arquivo não foi encontrado no GitHub.',
        code: 'DOWNLOAD_NOT_FOUND',
        endpoint: endpoint,
        stage: stage,
        httpStatus: status,
        apiMessage: apiMessage,
      );
    }
    if (status == 410) {
      return DownloadFailureException(
        'O arquivo ou artifact expirou e não está mais disponível.',
        code: 'DOWNLOAD_EXPIRED',
        endpoint: endpoint,
        stage: stage,
        httpStatus: status,
        apiMessage: apiMessage,
      );
    }

    return DownloadFailureException(
      status == null
          ? 'O GitHub não respondeu como esperado ao preparar o download.'
          : 'O GitHub retornou HTTP $status ao preparar o download.',
      code: 'DOWNLOAD_HTTP_${status ?? 'UNKNOWN'}',
      endpoint: endpoint,
      stage: stage,
      httpStatus: status,
      apiMessage: apiMessage,
    );
  }

  static String? _responseMessage(Object? data) {
    if (data is Map) {
      final message = data['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message.length > 500 ? '${message.substring(0, 500)}…' : message;
      }
    }
    if (data is String) {
      final value = data.trim();
      if (value.isNotEmpty) {
        return value.length > 500 ? '${value.substring(0, 500)}…' : value;
      }
    }
    return null;
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
