import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/projects/data/local_project_service.dart';
import 'package:github_manager/features/repositories/data/repository_project_info_service.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';

void main() {
  const nativeGradle = '''
android {
  namespace = "com.nomaderaiz.app"
  defaultConfig {
    applicationId = "com.nomaderaiz.app"
    versionCode = 100032
    versionName = "1.0.32-kotlin-alpha.5"
  }
}
''';

  test('ZIP Android nativo lê versão de app/build.gradle.kts', () async {
    final temp = await Directory.systemTemp.createTemp('gm-native-version-');
    addTearDown(() => temp.delete(recursive: true));

    final archive = Archive()
      ..addFile(ArchiveFile('app/build.gradle.kts', utf8.encode(nativeGradle).length, utf8.encode(nativeGradle)))
      ..addFile(ArchiveFile(
        'app/src/main/AndroidManifest.xml',
        utf8.encode('<manifest package="com.nomaderaiz.app" />').length,
        utf8.encode('<manifest package="com.nomaderaiz.app" />'),
      ));
    final bytes = ZipEncoder().encode(archive);
    final zip = File('${temp.path}/nomade.zip')..writeAsBytesSync(bytes);

    final preview = await LocalProjectService().analyzeZip(zip.path);

    expect(preview.projectType, 'Android');
    expect(preview.applicationId, 'com.nomaderaiz.app');
    expect(preview.version, '1.0.32-kotlin-alpha.5');
    expect(preview.versionCode, 100032);
  });

  test('repositório Android nativo lê versão de app/build.gradle.kts', () async {
    final client = _FakeGitHubApiClient(nativeGradle);
    final service = RepositoryProjectInfoService(client);
    const repository = GitHubRepository(
      id: 1,
      name: 'Nomade-Raiz',
      fullName: 'owner/Nomade-Raiz',
      isPrivate: false,
      isArchived: false,
      defaultBranch: 'main',
      updatedAt: null,
      htmlUrl: 'https://github.com/owner/Nomade-Raiz',
      language: 'Kotlin',
    );

    final info = await service.load(repository);

    expect(info.applicationId, 'com.nomaderaiz.app');
    expect(info.version, '1.0.32-kotlin-alpha.5');
    expect(info.versionCode, 100032);
    expect(info.technologies, contains('Kotlin'));
  });
}

class _FakeGitHubApiClient extends GitHubApiClient {
  _FakeGitHubApiClient(this.gradle) : super(SecureStorageService());

  final String gradle;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    dynamic data;
    if (path == '/repos/owner/Nomade-Raiz/contents') {
      data = <dynamic>[
        <String, dynamic>{'name': 'app', 'path': 'app', 'type': 'dir'},
      ];
    } else if (path == '/repos/owner/Nomade-Raiz/languages') {
      data = <String, dynamic>{'Kotlin': 1000};
    } else if (path == '/repos/owner/Nomade-Raiz/contents/app/build.gradle.kts') {
      data = <String, dynamic>{
        'encoding': 'base64',
        'content': base64.encode(utf8.encode(gradle)),
      };
    } else {
      throw StateError('Unexpected path: $path');
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: data as T,
      statusCode: 200,
    );
  }
}
