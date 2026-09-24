import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/security/secure_storage_service.dart';
import 'package:github_manager/core/utils/git_object_hash.dart';
import 'package:github_manager/features/projects/data/git_project_upload_service.dart';
import 'package:github_manager/features/projects/data/local_project_service.dart';

void main() {
  test('prévia separa novos, alterados e removidos sem remover workflow protegido', () async {
    final temp = await Directory.systemTemp.createTemp('gm-preview-');
    addTearDown(() => temp.delete(recursive: true));

    final same = 'igual'.codeUnits;
    final changed = 'novo'.codeUnits;
    final created = 'criado'.codeUnits;
    final archive = Archive()
      ..addFile(ArchiveFile('Projeto/a.txt', same.length, same))
      ..addFile(ArchiveFile('Projeto/b.txt', changed.length, changed))
      ..addFile(ArchiveFile('Projeto/c.txt', created.length, created));
    final zipBytes = ZipEncoder().encode(archive);
    final zip = File('${temp.path}/Projeto.zip')..writeAsBytesSync(zipBytes);
    final project = await LocalProjectService().analyzeZip(zip.path);

    final client = _PreviewClient(
      sameSha: GitObjectHash.blobSha(same),
      changedOldSha: GitObjectHash.blobSha('antigo'.codeUnits),
    );
    final preview = await GitProjectUploadService(client).previewZipSync(
      project: project,
      repositoryFullName: 'owner/repo',
      branch: 'main',
    );

    expect(preview.createdPaths, ['c.txt']);
    expect(preview.modifiedPaths, ['b.txt']);
    expect(preview.deletedPaths, ['d.txt']);
    expect(preview.unchangedCount, 1);
  });
}

class _PreviewClient extends GitHubApiClient {
  _PreviewClient({required this.sameSha, required this.changedOldSha})
      : super(SecureStorageService());

  final String sameSha;
  final String changedOldSha;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    dynamic data;
    if (path.endsWith('/git/ref/heads/main')) {
      data = <String, dynamic>{
        'object': <String, dynamic>{'sha': 'commit-sha'},
      };
    } else if (path.endsWith('/git/commits/commit-sha')) {
      data = <String, dynamic>{
        'tree': <String, dynamic>{'sha': 'tree-sha'},
      };
    } else if (path.endsWith('/git/trees/tree-sha')) {
      data = <String, dynamic>{
        'truncated': false,
        'tree': <dynamic>[
          <String, dynamic>{'path': 'a.txt', 'mode': '100644', 'type': 'blob', 'sha': sameSha, 'size': 5},
          <String, dynamic>{'path': 'b.txt', 'mode': '100644', 'type': 'blob', 'sha': changedOldSha, 'size': 6},
          <String, dynamic>{'path': 'd.txt', 'mode': '100644', 'type': 'blob', 'sha': 'stale-sha', 'size': 4},
          <String, dynamic>{
            'path': '.github/workflows/android.yml',
            'mode': '100644',
            'type': 'blob',
            'sha': 'workflow-sha',
            'size': 20,
          },
        ],
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
