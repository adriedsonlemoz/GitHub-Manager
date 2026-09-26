# Validação — GitHub Manager 2.0.105+200119

- `pubspec.yaml` e `github-manager.json` sincronizados em `2.0.105+200119`;
- detalhes de Builds preservam Logs, Repetir, APK, Excluir e Atualizar;
- falhas são renderizadas antes do resumo da execução;
- resumo exibe Evento, Branch, Duração e Etapas em blocos responsivos;
- mensagem de commit permanece disponível sem duplicação no cabeçalho;
- execução, versão, commit, horários e workflow permanecem disponíveis em **Detalhes técnicos**;
- diagnóstico detalhado e contexto do log permanecem disponíveis em seção expansível;
- tela de Novidades aponta somente para mudanças da 2.0.105;
- teste de contrato `repository_run_details_visual_contract_test.dart` cobre a nova hierarquia visual;
- o ZIP final deve conter somente código-fonte e documentação, sem APK.
