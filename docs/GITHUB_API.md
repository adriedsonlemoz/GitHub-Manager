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


## Enviar build após sincronização

O fluxo `Enviar build` não assume mais que atualizar `refs/heads/{branch}` significa que o Actions iniciou. Depois do commit, o app consulta `GET /repos/{owner}/{repo}/actions/runs?head_sha={sha}` e procura especificamente a execução do workflow de APK.

Se o APK não aparecer após algumas verificações, o app inspeciona o conteúdo dos workflows ativos. A seleção manual exige duas evidências estruturais: `workflow_dispatch` no bloco `on` e uma etapa em `jobs` que realmente gere ou publique APK. O nome do arquivo serve apenas para priorizar a busca. Em repositórios recém-criados, o fallback examina todos os YAMLs de `.github/workflows`, sem depender de `android-apk.yml`.

Isso evita três erros: considerar CI como se fosse build de APK, escolher um workflow apenas pelo nome e criar uma segunda execução quando o `push` já iniciou a build normalmente. A checagem pelo SHA é repetida imediatamente antes do `workflow_dispatch`.

O token precisa ter permissão de escrita em Actions para o fallback manual. Falhas de permissão são exibidas como erro real, sem esconder o commit já sincronizado.

## Jobs, steps e falhas

Jobs são obtidos por `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs`. Para um job com falha, o app tenta consultar annotations do check run e mostrar a primeira mensagem de nível `failure`; logs completos continuam disponíveis para download.

## Downloads

Downloads de logs, artifacts e ZIP do repositório usam endpoints autenticados do GitHub para obter o redirecionamento. Release Assets usam `/repos/{owner}/{repo}/releases/assets/{asset_id}` com `Accept: application/octet-stream`, aceitando resposta direta ou redirecionamento; por isso também funcionam em repositórios privados. URLs temporárias assinadas nunca são usadas como endpoint diagnóstico: erros preservam somente o endpoint original da API e mensagens técnicas removem parâmetros de URLs antes da persistência/log.

Falhas são classificadas, quando possível, em rede, autenticação, permissão, rate limit, 404, artifact expirado/410, URL temporária expirada, interrupção e falha de gravação em Downloads. Downloads ativos são persistidos; se o processo for encerrado, reaparecem como `Interrompido` e podem ser repetidos.

## Upload de ZIP

A importação usa refs, commits, trees e blobs. Arquivos-texto pequenos podem ser enviados diretamente como `content` da tree; binários e arquivos maiores usam blobs base64. Para arquivos maiores, o ZIP é descompactado para arquivo temporário, o SHA Git é calculado por stream e o JSON/base64 é enviado em fluxo, evitando manter o arquivo completo e sua codificação base64 simultaneamente na memória. Antes do commit, caminhos existentes que não aparecem no ZIP são enviados na tree com `sha: null`, garantindo sincronização completa. A branch é atualizada somente após o novo commit completo ser criado.

## Secrets

O valor do Secret é criptografado localmente com sealed box antes do envio. O fluxo usa `GET /repos/{owner}/{repo}/actions/secrets`, `GET /repos/{owner}/{repo}/actions/secrets/public-key`, `PUT /repos/{owner}/{repo}/actions/secrets/{name}` e `DELETE` no mesmo recurso. Token, valores de Secrets e chaves não podem ser registrados em logs.

O módulo aceita token fine-grained e clássico porque a autenticação usa `Authorization: Bearer`. Para fine-grained, a tela orienta `Secrets: Read and write`; no token clássico, `repo`. Erros HTTP preservam status, endpoint e mensagem da API no diagnóstico sanitizado.

Antes do PUT, o app valida 48 KB por Secret e o limite final de 100 Secrets do repositório, considerando substituições. Importações em lote continuam após uma falha individual e retornam resultado por nome sem incluir valores.

## Diagnóstico de permissões

A versão 2.0.27 adiciona um diagnóstico não destrutivo por repositório. O fluxo consulta `GET /user`, `GET /repos/{owner}/{repo}`, `GET /repos/{owner}/{repo}/contents`, `GET /repos/{owner}/{repo}/actions/workflows`, `GET /repos/{owner}/{repo}/actions/secrets` e `GET /repos/{owner}/{repo}/actions/permissions`. Nenhuma chamada de escrita é executada só para testar permissões.

Em PAT clássico, `X-OAuth-Scopes` é usado para identificar `repo`, `workflow` e `delete_repo` quando o GitHub expõe esses escopos. Em PAT fine-grained, o app usa os resultados reais de leitura e `X-Accepted-GitHub-Permissions` para explicar requisitos, mas não afirma conhecer permissões de escrita que o GitHub não expõe por introspecção. A interface marca essas operações como `Verifique no token` e mostra a permissão necessária.

O diagnóstico também considera o papel da conta retornado em `permissions` do repositório. Rate limit é tratado separadamente de falta de permissão para evitar falso diagnóstico. O relatório copiável não inclui o token.

## Retry

Retry automático de chamadas destrutivas não é utilizado. Na Central de Downloads, o usuário pode repetir explicitamente downloads falhos ou cancelados quando o endpoint de origem ainda é válido.


## Pré-checagem de permissões 2.0.28

Antes de ações críticas, o aplicativo reutiliza por até 3 minutos o último `RepositoryPermissionReport` compatível com o mesmo repositório e o mesmo token (token identificado apenas por SHA-256 em memória). Negação confirmada impede a chamada mutativa; resultados `unknown` de PAT fine-grained, rate limit ou falha temporária do diagnóstico não são convertidos em bloqueio. A operação real continua sendo a autoridade final quando a API não permite confirmar escrita sem mutação.
