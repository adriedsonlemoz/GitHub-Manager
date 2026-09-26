# GitHub Manager 2.0.101+200115

## Objetivo

Uniformizar o desenho das superfícies retangulares, registrar falhas que possam explicar mensagens de “o app parou” e garantir que as novidades de cada atualização sejam realmente exibidas uma vez após confirmação.

## Mudanças

- raio visual padrão de 4 px para cards, campos, botões, diálogos, snackbars, navegação e containers retangulares;
- pills/círculos deliberados de status continuam arredondados;
- nova tela **Configurações > Erros e telemetria**;
- captura global de erros Flutter/Dart e exceções assíncronas;
- captura do último crash nativo Android por `UncaughtExceptionHandler` instalado no `Application`;
- importação automática do crash nativo no próximo acesso;
- retenção de até 120 registros locais no SQLite;
- relatório copiável/exportável em `.txt`, com sanitização de padrões conhecidos de token, senha, API key e secret;
- nenhuma telemetria é enviada automaticamente;
- opção para desativar a captura local e limpar o histórico;
- tela **Novidades da atualização** marcada como vista somente ao tocar em **Continuar**;
- atalho **Novidades desta versão** em Configurações para reabrir o resumo manualmente.

## Identidade

- versionName: `2.0.101`
- versionCode: `200115`
- applicationId: `br.com.githubmanager.app`
