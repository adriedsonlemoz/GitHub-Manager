# Validação da v2.0.114

## Casos de teste incluídos

- Payload build -> rota de repositório, branch e execução.
- Payload de download/envio -> item escolhido na Central correspondente.
- Payloads legados e entradas inválidas.
- Ponte Flutter e `onNewIntent` na Activity, recuperação de evento de abertura a frio e serviços nativos.

## Testes manuais necessários no Android

1. Abrir o app, disparar e tocar em uma notificação de build. Deve abrir o detalhe da execução específica.
2. Repetir com o app minimizado e com o app encerrado. Conferir a navegação até o mesmo evento.
3. Clicar em notificações de download concluído, download falho, upload e download em andamento. A Central correta deve destacar o registro.
4. Tocar em notificação antiga: Builds antigas sem ID abrem a tela do repositório; downloads legados mantêm o registro.
5. Excluir uma execução ou limpar o histórico e clicar na notificação: exibir mensagem explicativa, sem crash.
6. Testar alternância de tema, notificações bloqueadas e retorno do Android à Activity já aberta.

## CI

```bash
bash tool/check_version_sync.sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
flutter test --no-pub
flutter build apk --release
```

Flutter/Dart e dispositivo Android não estão disponíveis para execução local; não declarar testes/compilação aprovados até a CI confirmar.
