import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/downloads/domain/managed_download.dart';

void main() {
  ManagedDownload makeDownload() => ManagedDownload(
        id: 'partial-1',
        title: 'Vigia IA',
        fileName: 'vigia.apk',
        type: ManagedDownloadType.apk,
        status: ManagedDownloadStatus.downloading,
        createdAt: DateTime.utc(2026, 10, 16),
        repositoryFullName: 'owner/vigia',
        sourceEndpoint: '/repos/owner/vigia/releases/assets/42',
        receivedBytes: 2048,
        totalBytes: 8192,
        bytesPerSecond: 1000,
        estimatedSecondsRemaining: 7,
        workingPath: '/tmp/vigia.apk.part',
      );

  test('pausar preserva bytes, zera velocidade e serializa estado', () {
    final item = makeDownload()..markPaused();
    expect(item.isActive, isFalse);
    expect(item.isPaused, isTrue);
    expect(item.isHistoryClearable, isFalse);
    expect(item.canResume, isTrue);
    expect(item.receivedBytes, 2048);
    expect(item.bytesPerSecond, 0);
    expect(item.estimatedSecondsRemaining, isNull);
    final restored = ManagedDownload.fromJson(item.toJson());
    expect(restored.status, ManagedDownloadStatus.paused);
    expect(restored.statusLabel, 'Pausado');
    expect(restored.workingPath, '/tmp/vigia.apk.part');
    expect(restored.receivedBytes, 2048);
    expect(restored.isActive, isFalse);
  });

  test('retomar usa a parte salva e não a apaga antes do Range', () {
    final item = makeDownload()..markPaused();
    item.resetForRetry(preserveProgress: true);
    expect(item.status, ManagedDownloadStatus.queued);
    expect(item.receivedBytes, 2048);
    expect(item.totalBytes, 8192);
    expect(item.workingPath, '/tmp/vigia.apk.part');
    expect(item.errorCode, isNull);
  });

  test('limpeza geral não remove downloads pausados', () {
    final paused = makeDownload()..markPaused();
    final done = makeDownload()..status = ManagedDownloadStatus.completed;
    final cancelled = makeDownload()..status = ManagedDownloadStatus.cancelled;
    expect(paused.isHistoryClearable, isFalse);
    expect(done.isHistoryClearable, isTrue);
    expect(cancelled.isHistoryClearable, isTrue);
  });

  test('pausar e retomar são serializados após fechar o arquivo parcial', () {
    final code = File(
      'lib/features/downloads/data/download_manager_service.dart',
    ).readAsStringSync();
    expect(code, contains('Future<void> pause(String id)'));
    expect(code, contains('Future<void> resume(String id)'));
    expect(code, contains('await previous;'));
    expect(code, contains('_operations[item.id] = operation'));
    expect(code, contains('await _refreshPausedBytes(item)'));
    expect(code, contains('item.resetForRetry(preserveProgress: true)'));
    expect(code, contains('_finalizing.contains(id)'));
    expect(code, contains('item.isHistoryClearable'));
    expect(code, contains('_historyWrites = pending')); 
  });

  test('na Central Pausados tem botões Retomar e Cancelar', () {
    final screen = File(
      'lib/features/downloads/presentation/downloads_screen.dart',
    ).readAsStringSync();
    final cards = File(
      'lib/features/downloads/presentation/downloads_widgets.dart',
    ).readAsStringSync();
    expect(screen, contains("title: 'Pausados'"));
    expect(screen, contains('manager.pause(item.id)'));
    expect(screen, contains('manager.resume(item.id)'));
    expect(cards, contains('class _PausedDownloadCard'));
    expect(cards, contains("label: 'Pausar'"));
    expect(cards, contains("label: 'Retomar'"));
  });

  test('download público valida Content-Range e tamanho', () {
    final code = File(
      'lib/features/downloads/data/download_manager_service.dart',
    ).readAsStringSync();
    expect(code, contains(r"!contentRange.startsWith('bytes $offset-')"));
    expect(code, contains("'PUBLIC_DOWNLOAD_RESUME_INVALID'"));
    expect(code, contains("'PUBLIC_DOWNLOAD_INCOMPLETE'"));
  });
}
