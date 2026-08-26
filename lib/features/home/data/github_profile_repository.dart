import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/features/home/domain/github_profile.dart';

class GitHubProfileRepository {
  GitHubProfileRepository(this._client, this._database);

  static const _cacheKey = 'github.profile';
  final GitHubApiClient _client;
  final LocalDatabase _database;

  Future<GitHubProfile> loadProfile() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/user');
      final profile = GitHubProfile.fromJson(
        response.data ?? const <String, dynamic>{},
      );
      await _database.putJson(_cacheKey, profile.toJson());
      return profile;
    } catch (_) {
      final cached = await _database.readJson(_cacheKey);
      if (cached is Map) {
        return GitHubProfile.fromJson(Map<String, dynamic>.from(cached));
      }
      rethrow;
    }
  }

  Future<GitHubProfile> updateProfile({
    required String name,
    required String email,
    required String blog,
    required String twitterUsername,
    required String company,
    required String location,
    required String bio,
    required bool hireable,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/user',
      data: {
        'name': name.trim(),
        'email': email.trim(),
        'blog': blog.trim(),
        'twitter_username': twitterUsername.trim().isEmpty
            ? null
            : twitterUsername.trim(),
        'company': company.trim(),
        'location': location.trim(),
        'bio': bio.trim(),
        'hireable': hireable,
      },
    );
    final profile = GitHubProfile.fromJson(
      response.data ?? const <String, dynamic>{},
    );
    await _database.putJson(_cacheKey, profile.toJson());
    return profile;
  }
}
