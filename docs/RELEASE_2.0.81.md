# GitHub Manager 2.0.81

Versão: `2.0.81+200095`

## Correções e melhorias

- A branch é escolhida antes do pré-check de sincronização e qualquer troca posterior executa novamente o pré-check antes do envio.
- Resposta válida do GitHub com zero branches é tratada como repositório vazio; o primeiro envio inicializa a branch padrão. Erros de rede/API continuam bloqueando a seleção em vez de serem mascarados.
- A comparação de versões segue SemVer: versões estáveis superam prereleases equivalentes, `alpha.10` supera `alpha.2`, identificadores numéricos seguem ordem numérica e `+build` não altera precedência.
- Builds global reduz chamadas à API: lista de repositórios em cache por 10 minutos, polling rápido apenas dos repositórios com run ativo e varredura completa a cada 3 minutos ou por atualização manual.
- Novo teste de widget percorre o fluxo real de Enviar: abre seletor, escolhe `develop`, confirma, desmarca a build e verifica que o upload é criado na branch escolhida após o pré-check.

## Validação

- Testes de contrato atualizados para ordem branch → pré-check e repositório vazio.
- Testes unitários adicionados para SemVer.
- Testes adicionados para cache/polling seletivo da tela Builds.
- `testWidgets` adicionado para o fluxo de envio pela interface.
- O ambiente de geração não inclui Flutter SDK; `flutter analyze` e `flutter test` devem ser confirmados pelo CI do projeto.
