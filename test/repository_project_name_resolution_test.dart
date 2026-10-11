import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/repositories/data/android_project_name_resolver.dart';
import 'package:github_manager/features/repositories/data/repository_project_info_service.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';

void main() {
  test('Android: resolve android:label no strings.xml', () {
    final result = AndroidProjectNameResolver.fromManifest('''
        <manifest xmlns:android="http://schemas.android.com/apk/res/android">
          <application android:label="@string/app_name" />
        </manifest>''', stringsXml: '''
        <resources><string name="app_name">Câmera &amp; Rede</string></resources>''');
    expect(result, 'Câmera & Rede');
  });

  test('Android: retorna nome literal e rejeita referência não resolvida', () {
    const manifest = '''
        <manifest xmlns:android="http://schemas.android.com/apk/res/android">
          <application android:label="@string/title" />
        </manifest>''';
    expect(AndroidProjectNameResolver.fromManifest(manifest), isNull);
    expect(AndroidProjectNameResolver.fromManifest('''
        <manifest xmlns:android="http://schemas.android.com/apk/res/android">
          <application android:label="App Real" />
        </manifest>'''), 'App Real');
    expect(AndroidProjectNameResolver.fromManifest('<xml invalid'), isNull);
  });

  test('metadados explícitos prevalecem sobre rótulo Android', () async {
    final summary = await RepositoryProjectInfoService(
      _ProjectInfoClient(withMetadata: true),
    ).loadSummary(_repo);
    expect(summary.projectName, 'Nome Oficial');
    expect(summary.nameSource, 'app_identity.json');
    expect(summary.version, '1.2.3');
  });

  test('Home resolve nome Android mesmo quando versão já veio do Gradle', () async {
    final client = _ProjectInfoClient();
    final service = RepositoryProjectInfoService(client);
    final summary = await service.loadSummary(_repo);
    expect(summary.projectName, 'Câmera da Casa');
    expect(summary.nameSource, 'AndroidManifest.xml / strings.xml');
    expect(summary.version, '1.2.3');
    expect(summary.metadataIssue, isNull);
    final full = await service.load(_repo);
    expect(full.projectName, 'Câmera da Casa');
    expect(full.version, '1.2.3');
  });
}

const _repo = GitHubRepository(
  id: 1,
  name: 'Camera-Kotlin',
  fullName: 'owner/Camera-Kotlin',
  isPrivate: false,
  isArchived: false,
  defaultBranch: 'main',
  updatedAt: null,
  htmlUrl: 'https://github.com/owner/Camera-Kotlin',
  language: 'Kotlin',
);

class _ProjectInfoClient extends GitHubApiClient {
  _ProjectInfoClient({this.withMetadata = false}) : super(SecureStorageService());
  final bool withMetadata;

  @override
  Future<Response<T>> get<T>(String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    dynamic result;
    final files = <String, String>{
      'app/build.gradle.kts': 'versionName = "1.2.3"\nversionCode = 123',
      'app/src/main/AndroidManifest.xml': '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="@string/app_name" /></manifest>''',
      'app/src/main/res/values/strings.xml': '<resources><string name="app_name">Câmera da Casa</string></resources>',
    };
    if (path == '/repos/owner/Camera-Kotlin/contents') {
      result = <dynamic>[
        {'name': 'app', 'type': 'dir', 'path': 'app'},
        if (withMetadata) {'name': 'app_identity.json', 'type': 'file', 'path': 'app_identity.json'},
      ];
    } else if (path == '/repos/owner/Camera-Kotlin/languages') {
      result = <String, dynamic>{'Kotlin': 1500};
    } else if (path == '/repos/owner/Camera-Kotlin/contents/app_identity.json' &&
        withMetadata) {
      result = <String, dynamic>{
        'encoding': 'base64',
        'content': base64.encode(utf8.encode(
            '{"displayName":"Nome Oficial","version":"1.2.3"}')),
      };
    } else if (path.startsWith('/repos/owner/Camera-Kotlin/contents/')) {
      final filename = path.substring('/repos/owner/Camera-Kotlin/contents/'.length);
      final contents = files[filename];
      if (contents == null) throw StateError('Arquivo ausente: $filename');
      result = {'encoding': 'base64', 'content': base64.encode(utf8.encode(contents))};
    } else {
      throw StateError('Caminho inesperado: $path');
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: result as T,
      statusCode: 200,
    );
  }
}
