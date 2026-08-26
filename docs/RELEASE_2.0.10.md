# GitHub Manager 2.0.10 (200024)

## Notificações de Builds

- Adicionado monitoramento periódico de GitHub Actions em segundo plano.
- O app avisa quando uma execução nova termina com sucesso, falha, é cancelada, excede o tempo ou exige atenção.
- A mesma execução não gera notificações repetidas.
- O monitor considera apenas execuções criadas depois da ativação do recurso, evitando avisos de builds antigas.
- A lista de repositórios próprios já conhecida pelo aplicativo é usada como base; o token continua sendo lido apenas do armazenamento seguro.
- O monitor exige conexão com a internet e respeita economia de bateria.
- No Android, o intervalo periódico é de aproximadamente 15 minutos; o sistema operacional pode atrasar a execução.
- Adicionado controle em Configurações para ativar/desativar os avisos.
- Em Android 13+, o app solicita a permissão oficial de notificações.
- Nenhum servidor, backend, Firebase ou serviço externo foi adicionado.

## Android

- Adicionada permissão `POST_NOTIFICATIONS`.
- Adicionado suporte de processamento periódico em segundo plano.
- Configurado core library desugaring exigido pelo pacote de notificações.

## Base preservada

Mantém todas as alterações da 2.0.9:
- Meus repositórios / Acompanhados;
- Releases públicas;
- exclusão permanente de runs e artifacts;
- exclusão de APKs anteriores;
- refresh de Builds sem piscar a tela inteira;
- popup de edição reformulado;
- badges de versão e branch;
- Central de Downloads;
- sincronização completa e detecção de ZIP idêntico.

## Validação desta entrega

- Estrutura Dart verificada.
- Workflows YAML validados estruturalmente.
- AndroidManifest.xml validado.
- JSON de identidade validado.
- Sincronização de versão validada.
- ZIP final testado quanto à integridade.

O ambiente usado para preparar esta entrega não possui Flutter/Dart instalados. A resolução das novas dependências e a compilação final devem ser confirmadas pelo GitHub Actions.
