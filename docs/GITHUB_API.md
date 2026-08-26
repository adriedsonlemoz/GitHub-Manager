# GitHub API

## REST
Todas as chamadas usam `X-GitHub-Api-Version: 2026-03-10` e `Accept: application/vnd.github+json`.

## Autenticação
Inicialmente por personal access token informado pelo usuário e guardado apenas no dispositivo.

## Upload eficiente
Fluxo planejado: obter commit/árvore base → criar blobs → criar tree usando `base_tree` → criar um commit → atualizar a ref. Isso evita um commit por arquivo.

## Secrets
Fluxo planejado: obter public key do repositório → criptografar localmente com LibSodium sealed box → enviar `encrypted_value` + `key_id` → descartar valor em memória assim que possível.

## Rate limit
Capturar futuramente `x-ratelimit-limit`, `x-ratelimit-remaining` e `x-ratelimit-reset`.

## Retry
Retry apenas para erros transitórios e operações idempotentes. Não repetir automaticamente ação destrutiva ambígua.


## Upload de ZIP

A importação usa refs, commits, trees e blobs. Arquivos-texto pequenos podem ser enviados diretamente como `content` da tree; binários e arquivos maiores usam blobs base64. A branch é atualizada somente após o commit completo ser criado.
