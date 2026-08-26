# GitHub API

## REST

Todas as chamadas usam `Accept: application/vnd.github+json` e a versão da API definida em `GitHubApi`. A autenticação é feita diretamente com o token guardado no aparelho.

## GitHub Actions

A fonte principal da tela Builds é:

`GET /repos/{owner}/{repo}/actions/runs`

A resposta é paginada e cada run mantém `workflow_id`, `path`, branch, SHA, título, status, conclusão e datas. A seleção de um workflow é filtrada localmente por `workflow_id` e, como fallback, pelo path normalizado.

Se o filtro retornar zero, o app tenta diagnosticar também:

- `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}/runs`;
- `GET /repos/{owner}/{repo}/actions/workflows/{workflow_file_name}/runs`.

A interface diferencia API vazia, filtro sem correspondência e erro de consulta. O diagnóstico nunca inclui token ou `Authorization`.

## Jobs, steps e falhas

Jobs são obtidos por `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs`. Para um job com falha, o app tenta consultar annotations do check run e mostrar a primeira mensagem de nível `failure`; logs completos continuam disponíveis para download.

## Downloads

Downloads de logs, artifacts e ZIP do repositório usam o endpoint autenticado do GitHub apenas para obter o redirecionamento. A URL temporária assinada é consumida em memória e não é persistida nem exibida no log.

Falhas são classificadas, quando possível, em rede, autenticação, permissão, rate limit, 404, artifact expirado/410, URL temporária expirada, interrupção e falha de gravação em Downloads.

## Upload de ZIP

A importação usa refs, commits, trees e blobs. Arquivos-texto pequenos podem ser enviados diretamente como `content` da tree; binários e arquivos maiores usam blobs base64. Antes do commit, caminhos existentes que não aparecem no ZIP são enviados na tree com `sha: null`, garantindo sincronização completa. A branch é atualizada somente após o novo commit completo ser criado.

## Secrets

O valor do Secret é criptografado localmente com sealed box antes do envio. Token, Secrets e chaves não podem ser registrados em logs.

## Retry

Retry automático de chamadas destrutivas não é utilizado. Na Central de Downloads, o usuário pode repetir explicitamente downloads falhos ou cancelados quando o endpoint de origem ainda é válido.
