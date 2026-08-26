class GitHubProfile {
  const GitHubProfile({
    required this.login,
    required this.avatarUrl,
    required this.publicRepos,
    required this.privateRepos,
    this.name,
    this.email,
    this.blog,
    this.twitterUsername,
    this.company,
    this.location,
    this.bio,
    this.hireable = false,
  });

  final String login;
  final String? name;
  final String avatarUrl;
  final int publicRepos;
  final int privateRepos;
  final String? email;
  final String? blog;
  final String? twitterUsername;
  final String? company;
  final String? location;
  final String? bio;
  final bool hireable;

  int get repositoryCount => publicRepos + privateRepos;

  factory GitHubProfile.fromJson(Map<String, dynamic> json) => GitHubProfile(
        login: json['login'] as String? ?? '',
        name: json['name'] as String?,
        avatarUrl: json['avatar_url'] as String? ?? '',
        publicRepos: (json['public_repos'] as num?)?.toInt() ?? 0,
        privateRepos: (json['total_private_repos'] as num?)?.toInt() ?? 0,
        email: json['email'] as String?,
        blog: json['blog'] as String?,
        twitterUsername: json['twitter_username'] as String?,
        company: json['company'] as String?,
        location: json['location'] as String?,
        bio: json['bio'] as String?,
        hireable: json['hireable'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'login': login,
        'name': name,
        'avatar_url': avatarUrl,
        'public_repos': publicRepos,
        'total_private_repos': privateRepos,
        'email': email,
        'blog': blog,
        'twitter_username': twitterUsername,
        'company': company,
        'location': location,
        'bio': bio,
        'hireable': hireable,
      };
}
