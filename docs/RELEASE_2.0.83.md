# GitHub Manager 2.0.83

Versão: `2.0.83+200097`
Data: 2026-09-24

## Entrega

- Builds global com um único card por repositório;
- somente os workflows do commit/versão mais recente são mantidos na fotografia global;
- pop-up por repositório mostra uma ou várias builds atuais, como CI + Android APK;
- ações rápidas para baixar logs e APKs de cada execução;
- atualização de tela a cada 6 s, com polling seletivo de repositórios ativos e varredura completa a cada 1 minuto;
- correção dos erros fatais dos logs #72 em `LocalProjectService` e na nulabilidade de `RepositoryBranch`;
- warnings diretamente relacionados à entrega recente limpos;
- testes de agrupamento, popup e navegação atualizados.

## Validação

Execute no CI: `flutter analyze` e `flutter test`. O script `tool/check_version_sync.sh` deve confirmar `2.0.83+200097`.
