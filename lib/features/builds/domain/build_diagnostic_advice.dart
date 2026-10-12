/// Orientações conservadoras para erros recorrentes. O texto não altera código
/// e nunca substitui a mensagem literal do compilador.
class BuildDiagnosticAdvice {
  const BuildDiagnosticAdvice({required this.title, required this.action});
  final String title;
  final String action;

  static BuildDiagnosticAdvice fromMessage(String message) {
    final text = message.toLowerCase();
    if (text.contains('unresolved reference') ||
        text.contains('cannot find symbol') ||
        text.contains('undefined name') ||
        text.contains("isn't defined")) {
      return const BuildDiagnosticAdvice(
        title: 'Símbolo ou referência não encontrada',
        action: 'Confira imports, nome do símbolo e dependências no arquivo indicado. '
            'Não acrescente imports sem verificar onde o símbolo está declarado.',
      );
    }
    if (text.contains('expected:') && text.contains('actual:') ||
        text.contains('test failed') || text.contains('tests failed')) {
      return const BuildDiagnosticAdvice(
        title: 'Teste automatizado falhou',
        action: 'Abra o primeiro teste com falha e compare o resultado esperado '
            'com o obtido. Um resumo de testes não identifica a causa sozinho.',
      );
    }
    if (text.contains('permission denied') || text.contains('403 forbidden')) {
      return const BuildDiagnosticAdvice(
        title: 'Permissão insuficiente',
        action: 'Confira as permissões do GITHUB_TOKEN/PAT, o escopo do '
            'workflow e o recurso que retornou a recusa.',
      );
    }
    if (text.contains('resource linking failed') || text.contains('aapt2')) {
      return const BuildDiagnosticAdvice(
        title: 'Erro nos recursos Android',
        action: 'Verifique recursos XML, nomes de drawables e referências '
            'na primeira mensagem de erro do AAPT2.',
      );
    }
    return const BuildDiagnosticAdvice(
      title: 'Falha da execução',
      action: 'Confira o arquivo, a linha e o primeiro erro específico no log. '
          'Mensagens finais de resumo não são suficientes para propor correção.',
    );
  }
}
