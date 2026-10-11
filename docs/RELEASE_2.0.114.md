# GitHub Manager 2.0.114+200128

## Notificações acionáveis

- Toque em uma build abre o detalhe da execução no repositório, respeitando branch e ID (inclusive execução fora do histórico recente exibido).
- Toque em notificações de download concluído/com falha abre Central de Downloads destacando o registro; tocar no destaque abre os detalhes.
- Toque nas notificações dos serviços Android de upload/download em andamento abre a Central correspondente destacando a transferência.
- A navegação funciona com o app em primeiro plano, em segundo plano ou iniciado pelo toque, conforme o ciclo de vida de Flutter/Android.
- Sucessos são informativos e discretos; falhas recebem canal de maior prioridade. O Android permite ajustar canais nas configurações do sistema.
- Mantém o tratamento de payloads legados e rejeita destinos externos não suportados.

## Verificação

Executar `bash tool/check_version_sync.sh`, `flutter analyze`, `flutter test` e o workflow Android APK. Validar os três cenários de clique em aparelho real. O projeto não foi compilado no ambiente de edição.
