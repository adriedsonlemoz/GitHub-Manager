import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/features/repositories/data/play_readiness_service.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/play_readiness_report.dart';

void main() {
  final paths = [
    'android/app/build.gradle.kts',
    'android/app/src/main/AndroidManifest.xml',
    'pubspec.yaml',
    '.github/workflows/android.yml',
  ];

  test('API 36 literal é reconhecida; compileSdk não é tratado como targetSdk', () {
    final checks = PlayReadinessService.evaluateSources(
      paths: paths,
      completeTree: true,
      gradlePath: 'android/app/build.gradle.kts',
      gradle: '''android { compileSdk = 36
        defaultConfig { applicationId = "com.exemplo.app"
          targetSdk = 35
          versionCode = 42
        }
      }''',
      manifestPath: 'android/app/src/main/AndroidManifest.xml',
      manifest: '<manifest/>',
      pubspec: 'version: 1.0.0+42',
    );
    expect(checks.first.state, PlayCheckState.attention);
    expect(checks.first.detail, contains('35'));
    expect(checks[1].state, PlayCheckState.unknown);
    expect(checks[2].state, PlayCheckState.verified);
    expect(checks[3].state, PlayCheckState.verified);
  });

  test('API 36 literal cumpre requisito técnico; Flutter dinâmico permanece incerto', () {
    final verified = PlayReadinessService.evaluateSources(
      paths: paths,
      completeTree: true,
      gradlePath: 'android/app/build.gradle.kts',
      gradle: 'targetSdk = 36',
      manifestPath: null,
      manifest: null,
      pubspec: 'version: 1.1+9',
    );
    final dynamic = PlayReadinessService.evaluateSources(
      paths: paths,
      completeTree: true,
      gradlePath: 'android/app/build.gradle.kts',
      gradle: 'compileSdk = 36\ntargetSdk = flutter.targetSdkVersion',
      manifestPath: null,
      manifest: null,
      pubspec: 'version: 1.1+9',
    );
    expect(verified.first.state, PlayCheckState.verified);
    expect(dynamic.first.state, PlayCheckState.unknown);
  });

  test('reconhece sinais do bundle sem declarar que AAB foi validado', () {
    final checks = PlayReadinessService.evaluateSources(
      paths: paths,
      completeTree: true,
      gradlePath: null,
      gradle: null,
      manifestPath: null,
      manifest: null,
      pubspec: null,
      workflowContents: {'.github/workflows/android.yml': 'run: flutter build appbundle --release'},
    );
    expect(checks.first.state, PlayCheckState.unknown);
    final aab = checks.singleWhere((item) => item.title.contains('App Bundle'));
    expect(aab.state, PlayCheckState.unknown);
    expect(aab.detail, contains('não comprova compilação'));
  });

  test('GitHub API é consultada por árvore e arquivos permitidos', () async {
    final fake = _FakePlayClient();
    final result = await PlayReadinessService(fake).inspect(_repo);
    expect(result.androidProject, true);
    expect(result.completeTree, true);
    expect(result.verified, greaterThanOrEqualTo(2));
    expect(result.manual.length, greaterThanOrEqualTo(3));
    expect(fake.requested, isNot(contains('keystore')));
    expect(fake.requested.where((path) => path.contains('/contents/')), hasLength(3));
  });

  test('repositório de site estático não é classificado como app Android', () async {
    final fake = _FakePlayClient(web: true);
    final result = await PlayReadinessService(fake).inspect(_repo);
    expect(result.androidProject, false);
    expect(result.automatic, isEmpty);
  });
}

const _repo = GitHubRepository(
  id: 99,
  name: 'teste',
  fullName: 'owner/teste',
  isPrivate: false,
  isArchived: false,
  defaultBranch: 'main',
  updatedAt: null,
  htmlUrl: 'https://github.com/owner/teste',
);

class _FakePlayClient extends GitHubApiClient {
  _FakePlayClient({this.web = false}) : super(SecureStorageService());

  final bool web;
  final List<String> requested = [];

  @override
  Future<Response<T>> get<T>(String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    requested.add(path);
    dynamic data;
    if (path.contains('/git/trees/')) {
      data = {
        'truncated': false,
        'tree': (web ? ['index.html', 'styles.css'] : [
          'app/build.gradle.kts',
          'app/src/main/AndroidManifest.xml',
          'pubspec.yaml',
        ]).map((item) => {'path': item, 'type': 'blob'}).toList(),
      };
    } else if (path.contains('/contents/')) {
      final content = path.endsWith('/build.gradle.kts')
          ? 'android { defaultConfig { targetSdk = 36\nversionCode = 32\napplicationId = "br.com.teste" } }'
          : path.endsWith('/AndroidManifest.xml')
              ? '<manifest/>'
              : 'version: 1.0.0+32';
      data = {'encoding': 'base64', 'content': base64.encode(utf8.encode(content))};
    } else {
      throw StateError('Consulta inesperada: $path');
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: data as T,
      statusCode: 200,
    );
  }
}
