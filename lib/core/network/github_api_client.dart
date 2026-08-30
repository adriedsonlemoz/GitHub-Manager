import 'dart:convert';
import 'dart:io';

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

  Future<Response<T>> uploadBinary<T>({
    required String url,
    required Stream<List<int>> stream,
    required int contentLength,
    required String contentType,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final token = await _secureStorage.readGitHubToken();
    if (token == null) {
      throw const AuthenticationRequiredException();
    }
    try {
      return await _dio.post<T>(
        url,
        data: stream,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': contentType,
            'Content-Length': contentLength,
            'Accept': GitHubApi.accept,
            'X-GitHub-Api-Version': GitHubApi.apiVersion,
          },
        ),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Response<T>> postBase64File<T>(
    String path,
    File file, {
    CancelToken? cancelToken,
  }) async {
    final token = await _secureStorage.readGitHubToken();
    if (token == null) {
      throw const AuthenticationRequiredException();
    }

    final fileLength = await file.length();
    const prefix = '{"content":"';
    const suffix = '","encoding":"base64"}';
    final base64Length = ((fileLength + 2) ~/ 3) * 4;
    final contentLength = utf8.encode(prefix).length +
        base64Length +
        utf8.encode(suffix).length;

    Stream<List<int>> body() async* {
      yield utf8.encode(prefix);
      await for (final chunk in base64.encoder.bind(file.openRead())) {
        yield utf8.encode(chunk);
      }
      yield utf8.encode(suffix);
    }

    try {
      return await _dio.post<T>(
        path,
        data: body(),
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 2),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Content-Length': contentLength,
            'Accept': GitHubApi.accept,
            'X-GitHub-Api-Version': GitHubApi.apiVersion,
          },
        ),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<void> downloadRedirectedFile(
    String path,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    int resumeFrom = 0,
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

    try {
      await _downloadTemporaryUrl(
        location,
        savePath,
        diagnosticEndpoint: path,
        resumeFrom: resumeFrom,
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

  Future<void> downloadReleaseAssetFile(
    String path,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    int resumeFrom = 0,
  }) async {
    final token = await _secureStorage.readGitHubToken();
    if (token == null) {
      throw const AuthenticationRequiredException();
    }

    Future<Response<ResponseBody>> request(int offset) =>
        _dio.get<ResponseBody>(
          path,
          cancelToken: cancelToken,
          options: Options(
            followRedirects: false,
            validateStatus: (_) => true,
            responseType: ResponseType.stream,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/octet-stream',
              if (offset > 0) 'Range': 'bytes=$offset-',
            },
          ),
        );

    Response<ResponseBody> response;
    try {
      response = await request(resumeFrom);
      if (response.statusCode == 416 && resumeFrom > 0) {
        final partial = File(savePath);
        if (await partial.exists()) await partial.delete();
        resumeFrom = 0;
        response = await request(0);
      }
    } on DioException catch (error) {
      throw _mapDownloadDioException(
        error,
        endpoint: path,
        stage: 'obter_release_asset',
      );
    }

    final status = response.statusCode;
    if (status == 200 || status == 206) {
      final body = response.data;
      if (body == null) {
        throw DownloadFailureException(
          'O GitHub não retornou o conteúdo do arquivo da Release.',
          code: 'RELEASE_ASSET_EMPTY',
          endpoint: path,
          stage: 'baixar_release_asset',
          httpStatus: status,
        );
      }
      await _writeResponseBody(
        response,
        body,
        savePath,
        requestedResumeFrom: resumeFrom,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        endpoint: path,
        stage: 'baixar_release_asset',
      );
      return;
    }

    if (!_isRedirect(status)) {
      throw _downloadHttpFailure(
        endpoint: path,
        stage: 'obter_release_asset',
        status: status,
        data: null,
        remaining: response.headers.value('x-ratelimit-remaining'),
      );
    }

    final location = response.headers.value('location');
    if (location == null || location.isEmpty) {
      throw DownloadFailureException(
        'O GitHub não retornou a URL temporária do arquivo da Release.',
        code: 'RELEASE_ASSET_REDIRECT_MISSING',
        endpoint: path,
        stage: 'obter_release_asset',
        httpStatus: status,
      );
    }

    try {
      await _downloadTemporaryUrl(
        location,
        savePath,
        diagnosticEndpoint: path,
        resumeFrom: resumeFrom,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (error) {
      throw _mapDownloadDioException(
        error,
        endpoint: path,
        stage: 'baixar_release_asset',
        temporaryUrl: true,
      );
    }
  }

  Future<void> _downloadTemporaryUrl(
    String url,
    String savePath, {
    required String diagnosticEndpoint,
    required int resumeFrom,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 10),
        followRedirects: true,
      ),
    );

    Future<Response<ResponseBody>> request(int offset) =>
        dio.get<ResponseBody>(
          url,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            validateStatus: (status) => status == 200 || status == 206 || status == 416,
            headers: {if (offset > 0) 'Range': 'bytes=$offset-'},
          ),
        );

    var offset = resumeFrom;
    var response = await request(offset);
    if (response.statusCode == 416 && offset > 0) {
      final partial = File(savePath);
      if (await partial.exists()) await partial.delete();
      offset = 0;
      response = await request(0);
    }
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw DownloadFailureException(
        'O servidor não aceitou a retomada do download.',
        code: 'DOWNLOAD_RESUME_HTTP_${response.statusCode ?? 'UNKNOWN'}',
        endpoint: diagnosticEndpoint,
        stage: 'retomar_download',
        httpStatus: response.statusCode,
      );
    }
    final body = response.data;
    if (body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Resposta de download vazia.',
      );
    }
    await _writeResponseBody(
      response,
      body,
      savePath,
      requestedResumeFrom: offset,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      endpoint: diagnosticEndpoint,
      stage: 'baixar_arquivo',
    );
  }

  Future<void> _writeResponseBody(
    Response<ResponseBody> response,
    ResponseBody body,
    String savePath, {
    required int requestedResumeFrom,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    required String endpoint,
    required String stage,
  }) async {
    final acceptedResume = response.statusCode == 206 && requestedResumeFrom > 0;
    final startingBytes = acceptedResume ? requestedResumeFrom : 0;
    final file = File(savePath);
    final sink = file.openWrite(
      mode: acceptedResume ? FileMode.append : FileMode.write,
    );
    var received = startingBytes;
    final contentRange = response.headers.value('content-range');
    final rangeTotal = contentRange == null
        ? null
        : int.tryParse(contentRange.split('/').last.trim());
    final contentLength =
        int.tryParse(response.headers.value('content-length') ?? '');
    final total = rangeTotal ??
        (contentLength == null ? -1 : startingBytes + contentLength);
    try {
      await for (final chunk in body.stream) {
        if (cancelToken?.isCancelled == true) {
          throw DownloadFailureException(
            'Download cancelado.',
            code: 'DOWNLOAD_CANCELLED',
            endpoint: endpoint,
            stage: stage,
          );
        }
        sink.add(chunk);
        received += chunk.length;
        onReceiveProgress?.call(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<GitHubApiProbeResponse> probeGet(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final token = await _secureStorage.readGitHubToken();
    if (token == null) {
      throw const AuthenticationRequiredException();
    }

    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          validateStatus: (_) => true,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return GitHubApiProbeResponse(
        statusCode: response.statusCode,
        data: response.data,
        headers: response.headers,
      );
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
          apiMessage: null,
        );
      }
      return _downloadHttpFailure(
        endpoint: endpoint,
        stage: stage,
        status: status,
        data: temporaryUrl ? null : response?.data,
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
      apiMessage: temporaryUrl ? null : error.message,
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
    final endpoint = error.requestOptions.path;
    final apiMessage = _responseMessage(response?.data);

    if (status == 401) {
      return AuthenticationRequiredException(
        httpStatus: status,
        endpoint: endpoint,
        apiMessage: apiMessage,
      );
    }
    if (status == 404) {
      return GitHubNotFoundException(
        httpStatus: status,
        endpoint: endpoint,
        apiMessage: apiMessage,
      );
    }
    if (status == 429) {
      return GitHubRateLimitException(
        httpStatus: status,
        endpoint: endpoint,
        apiMessage: apiMessage,
      );
    }
    if (status == 403 && remaining == '0') {
      return GitHubRateLimitException(
        httpStatus: status,
        endpoint: endpoint,
        apiMessage: apiMessage,
      );
    }
    if (status == 403) {
      return GitHubPermissionException(
        httpStatus: status,
        endpoint: endpoint,
        apiMessage: apiMessage,
      );
    }
    if (status == 409) {
      return GitHubConflictException(
        httpStatus: status,
        endpoint: endpoint,
        apiMessage: apiMessage,
      );
    }
    if (status == 422) {
      return GitHubValidationException(
        httpStatus: status,
        endpoint: endpoint,
        apiMessage: apiMessage,
      );
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


class GitHubApiProbeResponse {
  const GitHubApiProbeResponse({
    required this.statusCode,
    required this.data,
    required this.headers,
  });

  final int? statusCode;
  final Object? data;
  final Headers headers;

  bool get isSuccess => statusCode != null && statusCode! >= 200 && statusCode! < 300;

  String? header(String name) => headers.value(name);
}
