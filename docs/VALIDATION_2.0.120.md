# Validação 2.0.120

- [x] Local: logs APK #109 e CI #108 conferidos: 201 testes aprovados, 2 falhas no mesmo contrato.
- [x] Local: ZIP contém workflow `ci.yml` de desativação e workflows APK/Release preservados.
- [ ] Após envio ao GitHub: confirmar que `.github/workflows/ci.yml` em `main` exibe apenas `workflow_dispatch`, com `if: ${{ false }}`.
- [ ] Após envio ao GitHub: verificar ausência de nova execução automática da CI antiga nos próximos pushes.
- [ ] Rodar `bash tool/check_version_sync.sh`, `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`, `flutter test --no-pub` e build Android real.
- [ ] Atualizar branch protection caso ainda exija o check antigo `Analisar e testar`.
- [ ] Se decidir excluir remotamente `ci.yml`, remover o mesmo arquivo do ZIP em uploads futuros.

O arquivo legado inativo evita duplicidade sem conceder permissão de exclusão. Ele não elimina o workflow da lista do GitHub Actions.
