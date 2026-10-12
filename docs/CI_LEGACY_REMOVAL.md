# Exclusão efetiva da CI antiga no GitHub

O arquivo `.github/workflows/ci.yml` foi omitido nos ZIPs 2.0.118 e 2.0.119, mas **continuou ativo no GitHub** porque o envio incremental preserva workflows ausentes do pacote. Os logs CI #107 e Android APK #108 e, posteriormente, CI #108 e Android APK #109 confirmaram o problema. O ZIP 2.0.120 inclui propositalmente um substituto **inativo** para sobrescrever a versão remota antiga.

## Alternativa sem exclusão: substituição automática no upload do ZIP 2.0.120

Se a exclusão remota por integração não for permitida (HTTP 403), envie o ZIP 2.0.120 pelo GitHub Manager para a branch `main`. O arquivo `ci.yml` incluído no ZIP substitui a definição antiga, conserva apenas `workflow_dispatch` e impede execução com `if: ${{ false }}`. Assim, **o CI antigo deixa de executar nos próximos pushes**. O teste de contrato aceita este estado inativo ou a remoção real, mas rejeita os triggers antigos.

A exclusão definitiva continua preferível. Após remover o arquivo no GitHub, o próximo envio do **mesmo ZIP 2.0.120** pode recriá-lo, pois agora ele está presente no pacote. Para manter a exclusão definitiva, remova também `ci.yml` dos ZIPs enviados posteriormente e não reenvie esta versão. O contrato de testes aceita a ausência do arquivo.

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
