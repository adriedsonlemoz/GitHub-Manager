import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/features/home/domain/github_profile.dart';

class GitHubProfileRepository {
  GitHubProfileRepository(this._client);

  final GitHubApiClient _client;

  Future<GitHubProfile> loadProfile() async {
    final response = await _client.get<Map<String, dynamic>>('/user');
    return GitHubProfile.fromJson(
      response.data ?? const <String, dynamic>{},
    );
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
    return GitHubProfile.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }
}
