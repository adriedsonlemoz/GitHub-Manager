# GitHub Manager 2.0.5 (200019)

## Envio repetido do mesmo ZIP

O envio de projeto agora detecta quando a árvore Git resultante é idêntica à árvore atual do repositório.

Quando não existe alteração real:

- nenhum novo commit é criado;
- a branch não é atualizada;
- nenhuma build automática é disparada;
- o aplicativo informa `Projeto já está atualizado`;
- o commit atual é mostrado para identificação;
- existe a opção `Executar build mesmo assim`, que dispara manualmente `android-apk.yml` por `workflow_dispatch`.

Quando existe alteração, o fluxo anterior é preservado: cria o commit `Atualização • GitHub Manager • DD/MM/AAAA HH:mm:ss`, atualiza a branch e confirma/dispara o Android APK.

## Motivo

Evita commits e execuções do GitHub Actions duplicados quando o usuário envia exatamente o mesmo pacote mais de uma vez, sem impedir uma recompilação manual quando ela for desejada.

## Assinatura e build

Mantido o comportamento da 2.0.4: sem Secrets o workflow Android APK pode gerar APK de teste; com os quatro Secrets gera e valida a assinatura oficial; configuração parcial de Secrets é tratada como erro.

## Validação desta entrega

- sincronização de versão verificada por `tool/check_version_sync.sh`;
- três workflows YAML validados estruturalmente;
- `github-manager.json` validado como JSON;
- ZIP final verificado quanto à integridade.

O ambiente desta preparação não possui Flutter/Dart local; portanto a compilação desta versão só deve ser considerada aprovada depois do GitHub Actions executar o commit correspondente.
