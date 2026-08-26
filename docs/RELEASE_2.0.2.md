# GitHub Manager 2.0.2 (200016)

## Escopo

Esta versão mantém as correções de Builds, Actions, artifacts e Central de Downloads da 2.0.1 e corrige o fluxo de criação/sincronização usado pelo próprio GitHub Manager para garantir que `Enviar build` realmente resulte em uma build de APK.

## Repositório oficial

A fonte oficial do projeto é `adriedsonlemoz/GitHub-Manager`. O repositório anterior não deve ser usado como prova de execução da versão atual.

A auditoria mostrou que o repositório oficial foi criado pelo GitHub Manager, recebeu os três arquivos em `.github/workflows`, mas o commit inicial de importação ficou sem check-runs. O `POST /user/repos` com `auto_init: true` foi mantido; o problema estava no fluxo posterior, que atualizava a branch e assumia que o evento `push` sempre criaria a execução.

## Enviar build

O botão `Enviar build` agora executa um fluxo completo:

1. seleciona e valida o ZIP;
2. sincroniza completamente o repositório;
3. cria o commit `Atualização • GitHub Manager • DD/MM/AAAA HH:MM:SS`;
4. atualiza a branch;
5. consulta runs pelo `head_sha` do novo commit;
6. procura especificamente o workflow Android APK, sem confundir uma execução de CI com uma build;
7. se o push já iniciou o Android APK, não cria outra execução;
8. se não iniciou, aguarda a indexação e usa `workflow_dispatch`;
9. se a listagem de workflows ainda estiver vazia em um repositório recém-criado, verifica `.github/workflows/android-apk.yml` e tenta o dispatch pelo nome do arquivo;
10. se o projeto foi sincronizado mas a build não pôde ser confirmada/iniciada, a interface informa os dois estados separadamente e preserva o SHA do commit.

## Commits

Mensagens automáticas agora incluem segundos. A sincronização completa usa `Atualização` em vez de `Importa projeto`. Operações específicas de arquivo continuam com verbos próprios (`Cria`, `Atualiza`, `Exclui`, `Envia`).

## Criação de repositório

A criação via `POST /user/repos` com `auto_init: true` foi preservada porque a API cria corretamente o repositório e a branch inicial. A correção foi aplicada no primeiro envio do projeto e no disparo do Actions após a sincronização, onde o erro real ocorria.

## Builds/Actions e Downloads herdados da 2.0.1

- `/actions/runs` continua como fonte principal da tela Builds;
- `workflow_id` e `path` são preservados e usados no filtro local;
- diagnósticos distinguem API vazia, filtro e erro;
- jobs/steps e falhas continuam detalhados;
- APK/ZIP/logs/artifacts usam a Central de Downloads;
- APK direto de `upload-artifact@v7` com `archive: false` continua suportado;
- artifacts expirados permanecem visíveis;
- downloads salvam na pasta pública Downloads;
- token, Authorization, Secrets e URLs assinadas não entram nos logs.

## Validação

Nesta preparação foram validados estruturalmente os três YMLs, `github-manager.json`, `AndroidManifest.xml`, scripts shell, sincronização de versão e identidade antiga. Também foi feita verificação de delimitadores nos arquivos Dart alterados.

O ambiente desta sessão não possui Flutter/Dart instalados, portanto `flutter analyze`, `flutter test` e uma compilação local não foram executados. O código desta entrega deve ser considerado compilado apenas depois de uma execução correspondente no repositório oficial `adriedsonlemoz/GitHub-Manager`. A documentação não reutiliza runs do repositório anterior como prova de compilação.
