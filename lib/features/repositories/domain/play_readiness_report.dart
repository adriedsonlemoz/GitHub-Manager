enum PlayCheckState { verified, attention, unknown }

class PlayCheck {
  const PlayCheck({
    required this.title,
    required this.detail,
    required this.state,
    this.evidence,
  });

  final String title;
  final String detail;
  final PlayCheckState state;
  final String? evidence;
}

class PlayReadinessReport {
  const PlayReadinessReport({
    required this.branch,
    required this.androidProject,
    required this.completeTree,
    required this.automatic,
    required this.manual,
    this.note,
  });

  final String branch;
  final bool androidProject;
  final bool completeTree;
  final List<PlayCheck> automatic;
  final List<PlayCheck> manual;
  final String? note;

  /// Relatório completo em texto, pronto para compartilhar sem perder
  /// ressalvas, verificações manuais ou evidências do código-fonte.
  String toCopyText({required String repositoryFullName}) {
    final buffer = StringBuffer()
      ..writeln('RELATÓRIO DE PREPARAÇÃO PARA GOOGLE PLAY')
      ..writeln('Repositório: $repositoryFullName')
      ..writeln('Branch: $branch')
      ..writeln('Projeto Android identificado: ${androidProject ? 'Sim' : 'Não'}')
      ..writeln('Árvore do repositório: ${completeTree ? 'Completa' : 'Incompleta'}')
      ..writeln()
      ..writeln('Avaliação parcial do código-fonte. Não garante aprovação '
          'nem publicação na Play Console.');

    if (androidProject) {
      buffer
        ..writeln('Resumo técnico: verificados $verified, '
            'pontos de atenção $attention, não confirmados $unknown.')
        ..writeln();
    }

    if (note != null && note!.trim().isNotEmpty) {
      buffer
        ..writeln('Observação: ${note!.trim()}')
        ..writeln();
    }

    void writeChecks(String heading, List<PlayCheck> checks) {
      buffer.writeln(heading);
      if (checks.isEmpty) {
        buffer.writeln('Nenhuma verificação disponível.');
      } else {
        for (var index = 0; index < checks.length; index++) {
          final check = checks[index];
          final stateLabel = switch (check.state) {
            PlayCheckState.verified => 'VERIFICADO NO CÓDIGO',
            PlayCheckState.attention => 'ATENÇÃO',
            PlayCheckState.unknown => 'NÃO CONFIRMADO',
          };
          buffer
            ..writeln('${index + 1}. [$stateLabel] ${check.title}')
            ..writeln('   ${check.detail}');
          if (check.evidence?.trim().isNotEmpty == true) {
            buffer.writeln('   Fonte: ${check.evidence!.trim()}');
          }
        }
      }
      buffer.writeln();
    }

    writeChecks('VERIFICAÇÕES TÉCNICAS', automatic);
    writeChecks('CONFIRMAR NA PLAY CONSOLE', manual);
    return buffer.toString().trimRight();
  }

  int get verified => automatic.where((c) => c.state == PlayCheckState.verified).length;
  int get attention => automatic.where((c) => c.state == PlayCheckState.attention).length;
  int get unknown => automatic.where((c) => c.state == PlayCheckState.unknown).length;
}
