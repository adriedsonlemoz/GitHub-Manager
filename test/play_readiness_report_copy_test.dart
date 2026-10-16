import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/repositories/domain/play_readiness_report.dart';

void main() {
  test('copia todas as verificações, evidências e pendências sem omissões', () {
    const report = PlayReadinessReport(
      branch: 'main',
      androidProject: true,
      completeTree: false,
      note: 'A árvore do GitHub foi truncada.',
      automatic: [
        PlayCheck(
          title: 'targetSdk',
          detail: 'API 36 presente no Gradle.',
          evidence: 'android/app/build.gradle.kts',
          state: PlayCheckState.verified,
        ),
        PlayCheck(
          title: 'Assinatura Release',
          detail: 'Assinatura ainda não comprovada.',
          state: PlayCheckState.attention,
        ),
        PlayCheck(
          title: 'Bundle AAB',
          detail: 'AAB final não foi analisado.',
          state: PlayCheckState.unknown,
        ),
      ],
      manual: [
        PlayCheck(
          title: 'Segurança dos dados',
          detail: 'Conferir respostas no Play Console.',
          evidence: 'Play Console',
          state: PlayCheckState.unknown,
        ),
      ],
    );

    final text = report.toCopyText(repositoryFullName: 'proprietario/projeto');
    expect(text, startsWith('RELATÓRIO DE PREPARAÇÃO PARA GOOGLE PLAY'));
    expect(text, contains('Repositório: proprietario/projeto'));
    expect(text, contains('Branch: main'));
    expect(text, contains('Árvore do repositório: Incompleta'));
    expect(text, contains('Resumo técnico: verificados 1, pontos de atenção 1, não confirmados 1.'));
    expect(text, contains('Observação: A árvore do GitHub foi truncada.'));
    expect(text, contains('1. [VERIFICADO NO CÓDIGO] targetSdk'));
    expect(text, contains('API 36 presente no Gradle.'));
    expect(text, contains('Fonte: android/app/build.gradle.kts'));
    expect(text, contains('2. [ATENÇÃO] Assinatura Release'));
    expect(text, contains('3. [NÃO CONFIRMADO] Bundle AAB'));
    expect(text, contains('CONFIRMAR NA PLAY CONSOLE'));
    expect(text, contains('1. [NÃO CONFIRMADO] Segurança dos dados'));
    expect(text, contains('Fonte: Play Console'));
    expect(text, contains('Não garante aprovação nem publicação na Play Console.'));
  });

  test('site não Android mantém ressalva e não inventa verificações', () {
    const report = PlayReadinessReport(
      branch: 'develop',
      androidProject: false,
      completeTree: true,
      automatic: [],
      manual: [],
      note: 'O repositório não contém projeto Android reconhecido.',
    );
    final text = report.toCopyText(repositoryFullName: 'owner/site');
    expect(text, contains('Projeto Android identificado: Não'));
    expect(text, contains('Observação: O repositório não contém projeto Android reconhecido.'));
    expect(text, contains('Nenhuma verificação disponível.'));
    expect(text, isNot(contains('Resumo técnico:')));
  });
}
