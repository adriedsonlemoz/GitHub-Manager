import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/repositories/data/repository_git_service.dart';

void main() {
  test('README usa cache e atualização manual força nova consulta', () async {
    final client = _ReadmeClient();
    final service = RepositoryGitService(client);

    final first = await service.readReadme(
      repositoryFullName: 'owner/repo',
      branch: 'main',
    );
    final cached = await service.readReadme(
      repositoryFullName: 'owner/repo',
      branch: 'main',
    );
    final refreshed = await service.readReadme(
      repositoryFullName: 'owner/repo',
      branch: 'main',
      forceRefresh: true,
    );

    expect(first?.content, '# README 1');
    expect(cached?.content, '# README 1');
    expect(refreshed?.content, '# README 2');
    expect(client.readmeRequests, 2);
  });

  test('editar README invalida o cache da branch', () async {
    final client = _ReadmeClient();
    final service = RepositoryGitService(client);

    final file = await service.readReadme(
      repositoryFullName: 'owner/repo',
      branch: 'main',
    );
    await service.updateTextFile(
      repositoryFullName: 'owner/repo',
      branch: 'main',
      file: file!,
      content: '# editado',
      message: 'Atualiza README',
    );
    final reloaded = await service.readReadme(
      repositoryFullName: 'owner/repo',
      branch: 'main',
    );

    expect(client.updateRequests, 1);
    expect(client.readmeRequests, 2);
    expect(reloaded?.content, '# README 2');
  });
}

class _ReadmeClient extends GitHubApiClient {
  _ReadmeClient() : super(SecureStorageService());

  int readmeRequests = 0;
  int updateRequests = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    if (path != '/repos/owner/repo/readme') {
      throw StateError('Unexpected GET: $path');
    }
    readmeRequests++;
    final text = '# README $readmeRequests';
    final data = <String, dynamic>{
      'name': 'README.md',
      'path': 'README.md',
      'sha': 'sha-$readmeRequests',
      'size': utf8.encode(text).length,
      'encoding': 'base64',
      'content': base64.encode(utf8.encode(text)),
    };
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: data as T,
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    CancelToken? cancelToken,
  }) async {
    updateRequests++;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: <String, dynamic>{} as T,
      statusCode: 200,
    );
  }
}
