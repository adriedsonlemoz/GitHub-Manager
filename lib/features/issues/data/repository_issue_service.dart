import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/features/issues/domain/repository_issue.dart';

class RepositoryIssueService {
  RepositoryIssueService(this._client);

  final GitHubApiClient _client;

  Future<List<RepositoryIssue>> listIssues(
    String repositoryFullName, {
    String state = 'all',
  }) async {
    final issues = <RepositoryIssue>[];
    for (var page = 1; page <= 5; page++) {
      final response = await _client.get<List<dynamic>>(
        '/repos/$repositoryFullName/issues',
        queryParameters: {
          'state': state,
          'sort': 'updated',
          'direction': 'desc',
          'per_page': 100,
          'page': page,
        },
      );
      final raw = response.data ?? const <dynamic>[];
      final pageItems = raw
          .whereType<Map>()
          .where((json) => !json.containsKey('pull_request'))
          .map(
            (json) => RepositoryIssue.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList(growable: false);
      issues.addAll(pageItems);
      if (raw.length < 100) {
        break;
      }
    }
    return issues;
  }

  Future<RepositoryIssue> createIssue({
    required String repositoryFullName,
    required String title,
    required String body,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/repos/$repositoryFullName/issues',
      data: {
        'title': title.trim(),
        'body': body.trim(),
      },
    );
    return RepositoryIssue.fromJson(response.data ?? const {});
  }

  Future<RepositoryIssue> updateIssue({
    required String repositoryFullName,
    required int number,
    required String title,
    required String body,
    required String state,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/repos/$repositoryFullName/issues/$number',
      data: {
        'title': title.trim(),
        'body': body.trim(),
        'state': state,
      },
    );
    return RepositoryIssue.fromJson(response.data ?? const {});
  }
}
