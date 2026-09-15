# GitHub Manager 2.0.66

Versão: `2.0.66+200080`

## Correção do build 57

- Corrigida a falha `Required named parameter 'isFavorite' must be provided` no detalhe do repositório.
- O menu agora consulta o estado de projeto fixado antes de abrir, passa `isFavorite` corretamente e permite fixar/desafixar também pela tela interna do repositório.

## Identidade e versão de ZIP

- ZIPs Node/JavaScript passam a ler `name`, `displayName`, `productName`, `appName` e `version` do `package.json` da raiz.
- Também é aceito o formato comum em que todo o projeto está dentro de uma única pasta-raiz no ZIP.
- `package.json` de `node_modules` ou de pastas profundas não é usado como identidade do projeto.
- Isso corrige o cenário em que um projeto era detectado como Node/JavaScript, mas aparecia com **Versão do ZIP: Não identificada** mesmo tendo `version` no `package.json`.

## Conferir build

- Removido do diálogo o banner vermelho `GITHUB MANAGER INSTALADO`.
- O topo passa a mostrar **VERSÃO DO PROJETO A ENVIAR**.
- Se a versão não puder ser identificada, o quadro informa isso sem substituir pela versão do GitHub Manager.
- Avisos de identidade/versão recebem botão `?` com diagnóstico e instruções para corrigir em `package.json`, `pubspec.yaml`, Gradle, `github-manager.json` ou `VERSION`.

## Ajuda e chave GitHub

- Configurações ganha **Ajuda do aplicativo**, com guia geral sobre identidade, envios, Builds/APKs, token, Secrets e solução de problemas.
- A seção **Ajuda e segurança** passa a expor diretamente **Chave / token GitHub atual**.
- O token permanece oculto por padrão, pode ser exibido/ocultado e copiado quando o usuário solicitar.
- O valor continua armazenado somente no armazenamento seguro do Android e não deve ser incluído em logs ou diagnósticos.

## Validação

- Metadados de versão sincronizados.
- Teste adicionado para detecção de versão Node/JavaScript por `package.json` e para ignorar `package.json` profundo de `node_modules`.
- O ambiente local desta preparação não possui Flutter/Dart; a compilação e os testes completos devem ser confirmados pelo GitHub Actions.
