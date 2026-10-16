import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('atalho Play é quinto botão e abre auditoria do projeto', () {
    final screen = File('lib/features/repositories/presentation/repository_detail_screen.dart').readAsStringSync();
    final dialog = File('lib/features/repositories/presentation/play_readiness_dialog.dart').readAsStringSync();
    expect(screen, contains("label: 'Play'"));
    expect(screen, contains('Icons.storefront_outlined'));
    expect(screen, contains('showPlayReadinessDialog('));
    expect(screen, contains('PlayReadinessService('));
    expect(dialog, contains('Verificações técnicas'));
    expect(dialog, contains('Confirmar na Play Console'));
    expect(dialog, contains('Reavaliar'));
    expect(dialog, contains('Requisitos oficiais de API'));
    expect(dialog, contains("'Copiar relatório'"));
    expect(dialog, contains('Clipboard.setData(ClipboardData('));
    expect(dialog, contains('report.toCopyText('));
    expect(dialog, contains('snapshot.connectionState == ConnectionState.done'));
    expect(dialog, contains('snapshot.hasData && !snapshot.hasError'));
    expect(dialog, contains('Relatório copiado para a área de transferência.'));
  });
}
