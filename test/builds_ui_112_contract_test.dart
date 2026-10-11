import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('busca recolhida e filtros avançados na tela global', () {
    final code = File('lib/features/builds/presentation/global_builds_screen.dart').readAsStringSync();
    expect(code, contains("'Buscar builds'"));
    expect(code, contains("ValueKey('builds-advanced-toggle')"));
    expect(code, contains('if (_searchOpen)'));
    expect(code, contains('_apkSearches'));
  });

  test('fontes de APK são tratadas independentemente e detalhe sinaliza busca', () {
    final source = File('lib/features/repositories/presentation/repository_run_details_controller.dart').readAsStringSync();
    final visual = File('lib/features/repositories/presentation/repository_run_details.dart').readAsStringSync();
    expect(source, contains('var failedSources = 0;'));
    expect(visual, contains('if (_lookingForApks)'));
  });

  test('downloads e prévia preservam detalhes sem cortar ações', () {
    final downloads = File('lib/features/downloads/presentation/downloads_widgets.dart').readAsStringSync();
    final preview = File('lib/features/repositories/presentation/repository_detail_screen_actions.dart').readAsStringSync();
    expect(downloads, contains('_downloadDisplayName'));
    expect(downloads, contains("tooltip: 'Excluir do aparelho'"));
    expect(preview, contains('Copiar caminho completo'));
    expect(preview, contains("section('Removidos'"));
  });
}
