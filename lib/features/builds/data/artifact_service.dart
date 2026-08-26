import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';

class ArtifactService {
  ArtifactService(this._client);

  final GitHubApiClient _client;

  Future<List<ActionArtifact>> listArtifacts(String repositoryFullName) async {
    final artifacts = <ActionArtifact>[];
    for (var page = 1; page <= 5; page++) {
      final response = await _client.get<Map<String, dynamic>>(
        '/repos/$repositoryFullName/actions/artifacts',
        queryParameters: {'per_page': 100, 'page': page},
      );
      final raw = response.data?['artifacts'];
      if (raw is! List) {
        break;
      }
      final pageItems = raw
          .whereType<Map>()
          .map(
            (json) => ActionArtifact.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .where((item) => !item.expired)
          .toList(growable: false);
      artifacts.addAll(pageItems);
      if (raw.length < 100) {
        break;
      }
    }
    artifacts.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return artifacts;
  }

}
