# Exclusão efetiva da CI antiga no GitHub

O arquivo `.github/workflows/ci.yml` não existe desde o pacote 2.0.118, mas **pode continuar no GitHub** quando a atualização de arquivos for incremental. Os logs CI #107 e Android APK #108 da versão 2.0.118 mostram que o CI ainda existia no checkout; um arquivo ausente no ZIP não é uma instrução de exclusão.

## Remover pela interface GitHub

1. Abra o repositório `GitHub-Manager` na branch `main`.
2. Entre em **Code → .github → workflows → ci.yml**.
3. Use **Delete file** (Excluir arquivo) e faça o commit na branch correta.
4. Confirme que os workflows `android-apk.yml` e `android-release.yml` permanecem presentes.
5. Se o GitHub exigir o status do job antigo `Analisar e testar` nos rulesets/branch protection, atualize a exigência para o job atual de compilação, conforme a política do repositório.

## Remover com Git

```bash
git checkout main
git pull --ff-only
git rm .github/workflows/ci.yml
git commit -m "chore: remove CI duplicada"
git push origin main
```

Se o arquivo já estiver ausente, não execute `git rm`. O GitHub pode listar execuções antigas no histórico mesmo depois da exclusão do workflow; isso não significa que novos pushes continuarão disparando a CI.

## O que permanece

`android-apk.yml` verifica `bash tool/check_version_sync.sh`, `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings` e `flutter test --no-pub` antes de compilar o APK. `android-release.yml` também analisa e testa antes de gerar o APK oficial. A remoção de `ci.yml` elimina apenas a execução duplicada, **não os testes essenciais**.
