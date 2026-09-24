import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/repositories/data/repository_git_service.dart';

void main() {
  test('cria branch a partir do SHA da branch selecionada', () async {
    final client = _BranchClient();
    final service = RepositoryGitService(client);

    final branch = await service.createBranch(
      repositoryFullName: 'owner/repo',
      branchName: 'release/2.0.82',
      sourceBranch: 'develop',
    );

    expect(branch.name, 'release/2.0.82');
    expect(branch.sha, 'source-sha');
    expect(client.createdRef, 'refs/heads/release/2.0.82');
    expect(client.createdSha, 'source-sha');
  });

  test('lê limite atual da API GitHub', () async {
    final service = RepositoryGitService(_BranchClient());
    final rate = await service.loadRateLimit();
    expect(rate.limit, 5000);
    expect(rate.remaining, 4875);
    expect(rate.used, 125);
  });
}

class _BranchClient extends GitHubApiClient {
  _BranchClient() : super(SecureStorageService());

  String? createdRef;
  String? createdSha;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    dynamic data;
    if (path == '/repos/owner/repo/git/ref/heads/develop') {
      data = <String, dynamic>{
        'object': <String, dynamic>{'sha': 'source-sha'},
      };
    } else if (path == '/rate_limit') {
      data = <String, dynamic>{
        'resources': <String, dynamic>{
          'core': <String, dynamic>{
            'limit': 5000,
            'remaining': 4875,
            'used': 125,
            'reset': 1790251200,
          },
        },
      };
    } else {
      throw StateError('Unexpected GET: $path');
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: data as T,
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    if (path != '/repos/owner/repo/git/refs') {
      throw StateError('Unexpected POST: $path');
    }
    final map = Map<String, dynamic>.from(data! as Map);
    createdRef = map['ref'] as String?;
    createdSha = map['sha'] as String?;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: <String, dynamic>{} as T,
      statusCode: 201,
    );
  }
}
