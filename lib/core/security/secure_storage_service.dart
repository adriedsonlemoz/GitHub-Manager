import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:github_manager/core/security/github_token_normalizer.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _githubTokenKey = 'github.token.v1';
  static const _themeModeKey = 'app.theme_mode.v1';
  static const _apiProviderKey = 'api.provider.v1';
  static const _apiNameKey = 'api.name.v1';
  static const _apiBaseUrlKey = 'api.base_url.v1';
  static const _apiKeyKey = 'api.key.v1';
  static const _apiModelKey = 'api.model.v1';

  final FlutterSecureStorage _storage;

  Future<String?> readGitHubToken() async {
    final value = await _storage.read(key: _githubTokenKey);
    final token = value == null ? null : normalizeGitHubToken(value);
    return token == null || token.isEmpty ? null : token;
  }

  Future<void> writeGitHubToken(String token) =>
      _storage.write(key: _githubTokenKey, value: normalizeGitHubToken(token));

  Future<void> deleteGitHubToken() => _storage.delete(key: _githubTokenKey);

  Future<bool> hasGitHubToken() async => (await readGitHubToken()) != null;

  Future<String?> readThemeMode() => _storage.read(key: _themeModeKey);

  Future<void> writeThemeMode(String mode) =>
      _storage.write(key: _themeModeKey, value: mode);

  Future<Map<String, String>> readApiSettings() async {
    final values = await Future.wait([
      _storage.read(key: _apiProviderKey),
      _storage.read(key: _apiNameKey),
      _storage.read(key: _apiBaseUrlKey),
      _storage.read(key: _apiKeyKey),
      _storage.read(key: _apiModelKey),
    ]);
    return {
      'provider': values[0] ?? 'groq',
      'name': values[1] ?? 'Groq',
      'baseUrl': values[2] ?? 'https://api.groq.com/openai/v1',
      'apiKey': values[3] ?? '',
      'model': values[4] ?? '',
    };
  }

  Future<void> writeApiSettings({
    required String provider,
    required String name,
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    await Future.wait([
      _storage.write(key: _apiProviderKey, value: provider.trim()),
      _storage.write(key: _apiNameKey, value: name.trim()),
      _storage.write(key: _apiBaseUrlKey, value: baseUrl.trim()),
      _storage.write(key: _apiKeyKey, value: apiKey.trim()),
      _storage.write(key: _apiModelKey, value: model.trim()),
    ]);
  }
}
