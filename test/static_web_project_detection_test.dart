import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/projects/data/local_project_service.dart';

void main() {
  test('ZIP de portfólio HTML/CSS/JS é identificado como site estático', () async {
    final archive = Archive()
      ..addFile(_textFile('portfolio/index.html', '<title>Meu Site</title>'))
      ..addFile(_textFile('portfolio/styles.css', 'body{}'))
      ..addFile(_textFile('portfolio/app.js', 'console.log(1)'))
      ..addFile(_textFile('portfolio/vercel.json', '{}'))
      ..addFile(_textFile('portfolio/README.md', '# Meu Portfólio'));
    final bytes = ZipEncoder().encode(archive);
    final temp = await Directory.systemTemp.createTemp('gm-static-web-');
    addTearDown(() => temp.delete(recursive: true));
    final zip = File('${temp.path}/portfolio-v1.0.zip')
      ..writeAsBytesSync(bytes);

    final preview = await LocalProjectService().analyzeZip(zip.path);

    expect(preview.projectType, 'Site estático');
    expect(preview.fileCount, 5);
  });

  test('ZIP com página HTML na raiz é identificado sem package.json', () async {
    final archive = Archive()
      ..addFile(_textFile('index.html', '<!doctype html><title>Site</title>'));
    final temp = await Directory.systemTemp.createTemp('gm-static-html-');
    addTearDown(() => temp.delete(recursive: true));
    final zip = File('${temp.path}/site.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));

    final preview = await LocalProjectService().analyzeZip(zip.path);

    expect(preview.projectType, 'Site estático');
  });
}

ArchiveFile _textFile(String path, String content) {
  final bytes = utf8.encode(content);
  return ArchiveFile(path, bytes.length, bytes);
}
