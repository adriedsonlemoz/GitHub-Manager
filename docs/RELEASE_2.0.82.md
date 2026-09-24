# GitHub Manager 2.0.82

Versão: `2.0.82+200096`
Data: 2026-09-24

## Entrega

Esta versão conclui a segunda metade da auditoria iniciada na 2.0.80/2.0.81.

- seletor de branch compartilhado em Arquivos, Commits, Builds e Enviar versão;
- criação de branch pelo aplicativo a partir da branch atual;
- prévia read-only da sincronização com arquivos novos, alterados e removidos;
- detecção da raiz efetiva do projeto em ZIPs com subprojetos;
- inferência de versão pelo nome preservando `alpha`, `beta`, `rc`, `dev` e metadados SemVer;
- detecção de versão/identidade ampliada para Godot, Python e Rust;
- origem da versão e rate limit REST exibidos na conferência quando disponíveis;
- testes de regressão para os novos contratos.

## Validação

Execute no CI: `flutter analyze` e `flutter test`. O script `tool/check_version_sync.sh` deve confirmar `2.0.82+200096`.
