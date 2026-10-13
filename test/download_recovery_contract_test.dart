import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/downloads/data/download_speed_meter.dart';

void main() {
  test('progresso limita reconstruções e suaviza taxa', () {
    final code = File('lib/features/downloads/data/download_manager_service.dart')
        .readAsStringSync();
    final speed = File('lib/features/downloads/data/download_speed_meter.dart')
        .readAsStringSync();
    expect(speed, contains('const Duration(milliseconds: 350)'));
    expect(speed, contains('const Duration(seconds: 5)'));
    expect(speed, contains('final ListQueue<_ProgressPoint> _points'));
    expect(code, contains('if (!sample.shouldRefresh(now, finished: finished)) return;'));
    expect(code, contains('..receivedBytes = received'));
  });

  test('média da velocidade usa amostras temporais e limita redraws', () {
    final start = DateTime(2026, 10, 12);
    final meter = DownloadSpeedMeter(start, 0);
    expect(meter.shouldRefresh(start.add(const Duration(milliseconds: 200)),
        finished: false), isFalse);
    expect(meter.shouldRefresh(start.add(const Duration(milliseconds: 400)),
        finished: false), isTrue);
    final atOne = start.add(const Duration(seconds: 1));
    expect(meter.record(atOne, 1000000), closeTo(1000000, 1));
    final atTwo = start.add(const Duration(seconds: 2));
    expect(meter.record(atTwo, 2000000), closeTo(1000000, 1));
    // Uma pausa de rede longa não deve produzir pico artificial.
    final afterPause = start.add(const Duration(seconds: 8));
    expect(meter.record(afterPause, 2100000), lessThan(200000));
    expect(meter.shouldRefresh(afterPause, finished: true), isTrue);
  });

  test('recomeço do arquivo não mistura velocidades da tentativa anterior', () {
    final start = DateTime(2026, 10, 12);
    final meter = DownloadSpeedMeter(start, 1000);
    expect(meter.record(start.add(const Duration(seconds: 1)), 2000), 1000);
    expect(meter.record(start.add(const Duration(seconds: 2)), 0), 0);
    expect(meter.record(start.add(const Duration(seconds: 3)), 500), 500);
  });

  test('Releases e Artifacts renovam URL e retomam apenas erros transitórios', () {
    final code = File('lib/features/downloads/data/download_manager_service.dart')
        .readAsStringSync();
    expect(code, contains('Future<void> _downloadGithubWithRecovery('));
    expect(code, contains('attempt = 0; attempt < 3; attempt++'));
    expect(code, contains('await partialFile.length()'));
    expect(code, contains('resumeFrom: offset'));
    expect(code, contains("'DOWNLOAD_INCOMPLETE'"));
    expect(code, contains('if (cancelToken.isCancelled) return;'));
  });

  test('valida intervalo e detecta corpo menor que Content-Length', () {
    final code = File('lib/core/network/github_api_client.dart')
        .readAsStringSync();
    expect(code, contains(r"!contentRangeHeader.startsWith('bytes $requestedResumeFrom-')"));
    expect(code, contains("'DOWNLOAD_RESUME_INVALID'"));
    expect(code, contains('if (total >= 0 && received < total)'));
    expect(code, contains("'DOWNLOAD_INCOMPLETE'"));
  });
}
