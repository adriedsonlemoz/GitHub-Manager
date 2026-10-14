import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/projects/data/local_project_service.dart';

void main() {
  test('ZIP de site estático é identificado como Site estático', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('portfolio/index.html', 22, '<title>Meu Site</title>'))
      ..addFile(ArchiveFile('portfolio/styles.css', 6, 'body{}'))
      ..addFile(ArchiveFile('portfolio/app.js', 15, 'console.log(1)'))
      ..addFile(ArchiveFile('portfolio/vercel.json', 2, '{}'))
      ..addFile(ArchiveFile('portfolio/README.md', 16, '# Meu Portfólio'));
    final bytes = ZipEncoder().encode(archive)!;
    final temp = await Directory.systemTemp.createTemp('gm-static-web-');
    addTearDown(() => temp.delete(recursive: true));
    final zip = File('${temp.path}/portfolio-v1.0.zip')..writeAsBytesSync(bytes);

    final preview = await LocalProjectService().analyzeZip(zip.path);

    expect(preview.projectType, 'Site estático');
  });
}
