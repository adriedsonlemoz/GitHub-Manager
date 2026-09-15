import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/projects/data/local_project_service.dart';

void main() {
  test('ZIP Node lê nome e versão do package.json na pasta raiz', () async {
    final temp = await Directory.systemTemp.createTemp('gm-node-version-');
    addTearDown(() => temp.delete(recursive: true));

    const packageJson = '''
{
  "name": "eu-reciclo",
  "displayName": "Eu Reciclo",
  "version": "1.2.1"
}
''';
    final packageBytes = utf8.encode(packageJson);
    final indexBytes = utf8.encode('console.log("ok");');
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'Eu-Reciclo-v1.2.1/package.json',
          packageBytes.length,
          packageBytes,
        ),
      )
      ..addFile(
        ArchiveFile(
          'Eu-Reciclo-v1.2.1/index.js',
          indexBytes.length,
          indexBytes,
        ),
      );
    final bytes = ZipEncoder().encode(archive);
    final zip = File('${temp.path}/Eu-Reciclo-v1.2.1.zip')
      ..writeAsBytesSync(bytes);

    final preview = await LocalProjectService().analyzeZip(zip.path);

    expect(preview.projectType, 'Node/JavaScript');
    expect(preview.projectName, 'Eu Reciclo');
    expect(preview.packageName, 'eu-reciclo');
    expect(preview.version, '1.2.1');
    expect(preview.versionLabel, '1.2.1');
  });

  test('ignora package.json profundo de node_modules como identidade', () async {
    final temp = await Directory.systemTemp.createTemp('gm-node-nested-');
    addTearDown(() => temp.delete(recursive: true));

    final nestedBytes = utf8.encode('{"name":"dependency","version":"9.9.9"}');
    final indexBytes = utf8.encode('console.log("ok");');
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'project/node_modules/dependency/package.json',
          nestedBytes.length,
          nestedBytes,
        ),
      )
      ..addFile(
        ArchiveFile(
          'project/index.js',
          indexBytes.length,
          indexBytes,
        ),
      );
    final bytes = ZipEncoder().encode(archive);
    final zip = File('${temp.path}/project.zip')..writeAsBytesSync(bytes);

    final preview = await LocalProjectService().analyzeZip(zip.path);

    expect(preview.version, isNull);
    expect(preview.packageName, isNull);
  });
}
